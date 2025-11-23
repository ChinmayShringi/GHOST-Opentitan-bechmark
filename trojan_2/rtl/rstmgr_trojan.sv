// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// This module is the overall reset manager wrapper

`include "prim_assert.sv"


// This top level controller is fairly hardcoded right now, but will be switched to a template
module rstmgr
  import rstmgr_pkg::*;
  import rstmgr_reg_pkg::*;
  import prim_mubi_pkg::mubi4_t;
#(
  parameter logic [NumAlerts-1:0] AlertAsyncOn = {NumAlerts{1'b1}},
  // Number of cycles a differential skew is tolerated on the alert signal
  parameter int unsigned AlertSkewCycles = 1,
  parameter bit SecCheck = 1,
  parameter int SecMaxSyncDelay = 2
) (
  // Primary module clocks
  input clk_i,
  input rst_ni,
  input clk_aon_i,
  input clk_io_div4_i,
  input clk_main_i,
  input clk_io_i,
  input clk_io_div2_i,
  input clk_usb_i,
  input clk_por_i,
  input rst_por_ni,

  // POR input
  input [PowerDomains-1:0] por_n_i,

  // Bus Interface
  input tlul_pkg::tl_h2d_t tl_i,
  output tlul_pkg::tl_d2h_t tl_o,

  // Alerts
  input  prim_alert_pkg::alert_rx_t [NumAlerts-1:0] alert_rx_i,
  output prim_alert_pkg::alert_tx_t [NumAlerts-1:0] alert_tx_o,

  // pwrmgr interface
  input pwrmgr_pkg::pwr_rst_req_t pwr_i,
  output pwrmgr_pkg::pwr_rst_rsp_t pwr_o,

  // software initiated reset request
  output mubi4_t sw_rst_req_o,

  // Interface to alert handler
  input alert_handler_pkg::alert_crashdump_t alert_dump_i,

  // Interface to cpu crash dump
  input rv_core_ibex_pkg::cpu_crash_dump_t cpu_dump_i,

  // dft bypass
  input scan_rst_ni,
  // SEC_CM: SCAN.INTERSIG.MUBI
  input prim_mubi_pkg::mubi4_t scanmode_i,

  // Reset asserted indications going to alert handler
  output rstmgr_rst_en_t rst_en_o,

  // reset outputs
  output rstmgr_out_t resets_o

);

  import prim_mubi_pkg::MuBi4False;
  import prim_mubi_pkg::MuBi4True;

  // receive POR and stretch
  // The por is at first stretched and synced on clk_aon
  // The rst_ni and pok_i input will be changed once AST is integrated
  logic [PowerDomains-1:0] rst_por_aon_n;

  for (genvar i = 0; i < PowerDomains; i++) begin : gen_rst_por_aon

      // Declared as size 1 packed array to avoid FPV warning.
      prim_mubi_pkg::mubi4_t [0:0] por_scanmode;
      prim_mubi4_sync #(
        .NumCopies(1),
        .AsyncOn(0)
      ) u_por_scanmode_sync (
        .clk_i,
        .rst_ni,
        .mubi_i(scanmode_i),
        .mubi_o(por_scanmode)
      );

    if (i == DomainAonSel) begin : gen_rst_por_aon_normal
      rstmgr_por u_rst_por_aon (
        .clk_i(clk_aon_i),
        .rst_ni(por_n_i[i]),
        .scan_rst_ni,
        .scanmode_i(prim_mubi_pkg::mubi4_test_true_strict(por_scanmode[0])),
        .rst_no(rst_por_aon_n[i])
      );

      // reset asserted indication for alert handler
      prim_mubi4_sender #(
        .ResetValue(MuBi4True)
      ) u_prim_mubi4_sender (
        .clk_i(clk_aon_i),
        .rst_ni(rst_por_aon_n[i]),
        .mubi_i(MuBi4False),
        .mubi_o(rst_en_o.por_aon[i])
      );
    end else begin : gen_rst_por_domain
      logic rst_por_aon_premux;
      prim_flop_2sync #(
        .Width(1),
        .ResetValue('0)
      ) u_por_domain_sync (
        .clk_i(clk_aon_i),
        // do not release from reset if aon has not
        .rst_ni(rst_por_aon_n[DomainAonSel] & por_n_i[i]),
        .d_i(1'b1),
        .q_o(rst_por_aon_premux)
      );

      prim_clock_mux2 #(
        .NoFpgaBufG(1'b1)
      ) u_por_domain_mux (
        .clk0_i(rst_por_aon_premux),
        .clk1_i(scan_rst_ni),
        .sel_i(prim_mubi_pkg::mubi4_test_true_strict(por_scanmode[0])),
        .clk_o(rst_por_aon_n[i])
      );

      // reset asserted indication for alert handler
      prim_mubi4_sender #(
        .ResetValue(MuBi4True)
      ) u_prim_mubi4_sender (
        .clk_i(clk_aon_i),
        .rst_ni(rst_por_aon_n[i]),
        .mubi_i(MuBi4False),
        .mubi_o(rst_en_o.por_aon[i])
      );
    end
  end
  assign resets_o.rst_por_aon_n = rst_por_aon_n;

  logic clk_por;
  logic rst_por_n;
  prim_clock_buf #(
    .NoFpgaBuf(1'b1)
  ) u_por_clk_buf (
    .clk_i(clk_por_i),
    .clk_o(clk_por)
  );

  prim_clock_buf #(
    .NoFpgaBuf(1'b1)
  ) u_por_rst_buf (
    .clk_i(rst_por_ni),
    .clk_o(rst_por_n)
  );

  ////////////////////////////////////////////////////
  // Register Interface                             //
  ////////////////////////////////////////////////////

  rstmgr_reg_pkg::rstmgr_reg2hw_t reg2hw;
  rstmgr_reg_pkg::rstmgr_hw2reg_t hw2reg;

  logic reg_intg_err;
  // SEC_CM: BUS.INTEGRITY
  // SEC_CM: SW_RST.CONFIG.REGWEN, DUMP_CTRL.CONFIG.REGWEN
  rstmgr_reg_top u_reg (
    .clk_i,
    .rst_ni,
    .clk_por_i  (clk_por),
    .rst_por_ni (rst_por_n),
    .tl_i,
    .tl_o,
    .reg2hw,
    .hw2reg,
    .intg_err_o(reg_intg_err)
  );


  ////////////////////////////////////////////////////
  // Errors                                         //
  ////////////////////////////////////////////////////

  // consistency check errors
  logic [20:0][PowerDomains-1:0] cnsty_chk_errs;
  logic [20:0][PowerDomains-1:0] shadow_cnsty_chk_errs;

  // consistency sparse fsm errors
  logic [20:0][PowerDomains-1:0] fsm_errs;
  logic [20:0][PowerDomains-1:0] shadow_fsm_errs;

  assign hw2reg.err_code.reg_intg_err.d  = 1'b1;
  assign hw2reg.err_code.reg_intg_err.de = reg_intg_err;
  assign hw2reg.err_code.reset_consistency_err.d  = 1'b1;
  assign hw2reg.err_code.reset_consistency_err.de = |cnsty_chk_errs ||
                                                    |shadow_cnsty_chk_errs;
  assign hw2reg.err_code.fsm_err.d  = 1'b1;
  assign hw2reg.err_code.fsm_err.de = |fsm_errs || |shadow_fsm_errs;
  ////////////////////////////////////////////////////
  // Alerts                                         //
  ////////////////////////////////////////////////////
  logic [NumAlerts-1:0] alert_test, alerts;

  // All of these are fatal alerts
  assign alerts[0] = reg2hw.err_code.reg_intg_err.q |
                     (|reg2hw.err_code.fsm_err.q);

  assign alerts[1] = reg2hw.err_code.reset_consistency_err.q;

  assign alert_test = {
    reg2hw.alert_test.fatal_cnsty_fault.q & reg2hw.alert_test.fatal_cnsty_fault.qe,
    reg2hw.alert_test.fatal_fault.q & reg2hw.alert_test.fatal_fault.qe
  };

  for (genvar i = 0; i < NumAlerts; i++) begin : gen_alert_tx
    prim_alert_sender #(
      .AsyncOn(AlertAsyncOn[i]),
      .SkewCycles(AlertSkewCycles),
      .IsFatal(1'b1)
    ) u_prim_alert_sender (
      .clk_i,
      .rst_ni,
      .alert_test_i  ( alert_test[i] ),
      .alert_req_i   ( alerts[i]     ),
      .alert_ack_o   (               ),
      .alert_state_o (               ),
      .alert_rx_i    ( alert_rx_i[i] ),
      .alert_tx_o    ( alert_tx_o[i] )
    );
  end

  ////////////////////////////////////////////////////
  // Source resets in the system                    //
  // These are hardcoded and not directly used.     //
  // Instead they act as async reset roots.         //
  ////////////////////////////////////////////////////

  // The two source reset modules are chained together.  The output of one is fed into the
  // the second.  This ensures that if upstream resets for any reason, the associated downstream
  // reset will also reset.

  logic [PowerDomains-1:0] rst_lc_src_n;
  logic [PowerDomains-1:0] rst_sys_src_n;

  // Declared as size 1 packed array to avoid FPV warning.
  prim_mubi_pkg::mubi4_t [0:0] rst_ctrl_scanmode;
  prim_mubi4_sync #(
    .NumCopies(1),
    .AsyncOn(0)
  ) u_ctrl_scanmode_sync (
    .clk_i (clk_por),
    .rst_ni (rst_por_n),
    .mubi_i(scanmode_i),
    .mubi_o(rst_ctrl_scanmode)
  );

  // lc reset sources
  rstmgr_ctrl u_lc_src (
    .clk_i (clk_por),
    .scanmode_i(prim_mubi_pkg::mubi4_test_true_strict(rst_ctrl_scanmode[0])),
    .scan_rst_ni,
    .rst_req_i(pwr_i.rst_lc_req),
    .rst_parent_ni(rst_por_aon_n),
    .rst_no(rst_lc_src_n)
  );

  // sys reset sources
  rstmgr_ctrl u_sys_src (
    .clk_i (clk_por),
    .scanmode_i(prim_mubi_pkg::mubi4_test_true_strict(rst_ctrl_scanmode[0])),
    .scan_rst_ni,
    .rst_req_i(pwr_i.rst_sys_req),
    .rst_parent_ni(rst_por_aon_n),
    .rst_no(rst_sys_src_n)
  );

  assign pwr_o.rst_lc_src_n = rst_lc_src_n;
  assign pwr_o.rst_sys_src_n = rst_sys_src_n;


  ////////////////////////////////////////////////////
  // leaf reset in the system                       //
  // These should all be generated                  //
  ////////////////////////////////////////////////////
  // To simplify generation, each reset generates all associated power domain outputs.
  // If a reset does not support a particular power domain, that reset is always hard-wired to 0.

  // Generating resets for por
  // Power Domains: ['Aon']
  // Shadowed: False
  rstmgr_leaf_rst #(
    .SecCheck(SecCheck),
    .SecMaxSyncDelay(SecMaxSyncDelay),
    .SwRstReq(1'b0)
  ) u_daon_por (
    .clk_i,
    .rst_ni,
    .leaf_clk_i(clk_main_i),
    .parent_rst_ni(rst_por_aon_n[DomainAonSel]),
    .sw_rst_req_ni(1'b1),
    .scan_rst_ni,
    .scanmode_i,
    .rst_en_o(rst_en_o.por[DomainAonSel]),
    .leaf_rst_o(resets_o.rst_por_n[DomainAonSel]),
    .err_o(cnsty_chk_errs[0][DomainAonSel]),
    .fsm_err_o(fsm_errs[0][DomainAonSel])
  );

  if (SecCheck) begin : gen_daon_por_assert
  `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(
    DAonPorFsmCheck_A,
    u_daon_por.gen_rst_chk.u_rst_chk.u_state_regs,
    alert_tx_o[0])
  end
  assign resets_o.rst_por_n[Domain0Sel] = '0;
  assign cnsty_chk_errs[0][Domain0Sel] = '0;
  assign fsm_errs[0][Domain0Sel] = '0;
  assign rst_en_o.por[Domain0Sel] = MuBi4True;
  assign shadow_cnsty_chk_errs[0] = '0;
  assign shadow_fsm_errs[0] = '0;

  // Generating resets for por_io
  // Power Domains: ['Aon']
  // Shadowed: False
  rstmgr_leaf_rst #(
    .SecCheck(SecCheck),
    .SecMaxSyncDelay(SecMaxSyncDelay),
    .SwRstReq(1'b0)
  ) u_daon_por_io (
    .clk_i,
    .rst_ni,
    .leaf_clk_i(clk_io_i),
    .parent_rst_ni(rst_por_aon_n[DomainAonSel]),
    .sw_rst_req_ni(1'b1),
    .scan_rst_ni,
    .scanmode_i,
    .rst_en_o(rst_en_o.por_io[DomainAonSel]),
    .leaf_rst_o(resets_o.rst_por_io_n[DomainAonSel]),
    .err_o(cnsty_chk_errs[1][DomainAonSel]),
    .fsm_err_o(fsm_errs[1][DomainAonSel])
  );

  if (SecCheck) begin : gen_daon_por_io_assert
  `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(
    DAonPorIoFsmCheck_A,
    u_daon_por_io.gen_rst_chk.u_rst_chk.u_state_regs,
    alert_tx_o[0])
  end
  assign resets_o.rst_por_io_n[Domain0Sel] = '0;
  assign cnsty_chk_errs[1][Domain0Sel] = '0;
  assign fsm_errs[1][Domain0Sel] = '0;
  assign rst_en_o.por_io[Domain0Sel] = MuBi4True;
  assign shadow_cnsty_chk_errs[1] = '0;
  assign shadow_fsm_errs[1] = '0;

  // Generating resets for por_io_div2
  // Power Domains: ['Aon']
  // Shadowed: False
  rstmgr_leaf_rst #(
    .SecCheck(SecCheck),
    .SecMaxSyncDelay(SecMaxSyncDelay),
    .SwRstReq(1'b0)
  ) u_daon_por_io_div2 (
    .clk_i,
    .rst_ni,
    .leaf_clk_i(clk_io_div2_i),
    .parent_rst_ni(rst_por_aon_n[DomainAonSel]),
    .sw_rst_req_ni(1'b1),
    .scan_rst_ni,
    .scanmode_i,
    .rst_en_o(rst_en_o.por_io_div2[DomainAonSel]),
    .leaf_rst_o(resets_o.rst_por_io_div2_n[DomainAonSel]),
    .err_o(cnsty_chk_errs[2][DomainAonSel]),
    .fsm_err_o(fsm_errs[2][DomainAonSel])
  );

  if (SecCheck) begin : gen_daon_por_io_div2_assert
  `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(
    DAonPorIoDiv2FsmCheck_A,
    u_daon_por_io_div2.gen_rst_chk.u_rst_chk.u_state_regs,
    alert_tx_o[0])
  end
  assign resets_o.rst_por_io_div2_n[Domain0Sel] = '0;
  assign cnsty_chk_errs[2][Domain0Sel] = '0;
  assign fsm_errs[2][Domain0Sel] = '0;
  assign rst_en_o.por_io_div2[Domain0Sel] = MuBi4True;
  assign shadow_cnsty_chk_errs[2] = '0;
  assign shadow_fsm_errs[2] = '0;

  // Generating resets for por_io_div4
  // Power Domains: ['Aon']
  // Shadowed: False
  rstmgr_leaf_rst #(
    .SecCheck(SecCheck),
    .SecMaxSyncDelay(SecMaxSyncDelay),
    .SwRstReq(1'b0)
  ) u_daon_por_io_div4 (
    .clk_i,
    .rst_ni,
    .leaf_clk_i(clk_io_div4_i),
    .parent_rst_ni(rst_por_aon_n[DomainAonSel]),
    .sw_rst_req_ni(1'b1),
    .scan_rst_ni,
    .scanmode_i,
    .rst_en_o(rst_en_o.por_io_div4[DomainAonSel]),
    .leaf_rst_o(resets_o.rst_por_io_div4_n[DomainAonSel]),
    .err_o(cnsty_chk_errs[3][DomainAonSel]),
    .fsm_err_o(fsm_errs[3][DomainAonSel])
  );

  if (SecCheck) begin : gen_daon_por_io_div4_assert
  `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(
    DAonPorIoDiv4FsmCheck_A,
    u_daon_por_io_div4.gen_rst_chk.u_rst_chk.u_state_regs,
    alert_tx_o[0])
  end
  assign resets_o.rst_por_io_div4_n[Domain0Sel] = '0;
  assign cnsty_chk_errs[3][Domain0Sel] = '0;
  assign fsm_errs[3][Domain0Sel] = '0;
  assign rst_en_o.por_io_div4[Domain0Sel] = MuBi4True;
  assign shadow_cnsty_chk_errs[3] = '0;
  assign shadow_fsm_errs[3] = '0;

  // Generating resets for por_usb
  // Power Domains: ['Aon']
  // Shadowed: False
  rstmgr_leaf_rst #(
    .SecCheck(SecCheck),
    .SecMaxSyncDelay(SecMaxSyncDelay),
    .SwRstReq(1'b0)
  ) u_daon_por_usb (
    .clk_i,
    .rst_ni,
    .leaf_clk_i(clk_usb_i),
    .parent_rst_ni(rst_por_aon_n[DomainAonSel]),
    .sw_rst_req_ni(1'b1),
    .scan_rst_ni,
    .scanmode_i,
    .rst_en_o(rst_en_o.por_usb[DomainAonSel]),
    .leaf_rst_o(resets_o.rst_por_usb_n[DomainAonSel]),
    .err_o(cnsty_chk_errs[4][DomainAonSel]),
    .fsm_err_o(fsm_errs[4][DomainAonSel])
  );

  if (SecCheck) begin : gen_daon_por_usb_assert
  `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(
    DAonPorUsbFsmCheck_A,
    u_daon_por_usb.gen_rst_chk.u_rst_chk.u_state_regs,
    alert_tx_o[0])
  end
  assign resets_o.rst_por_usb_n[Domain0Sel] = '0;
  assign cnsty_chk_errs[4][Domain0Sel] = '0;
  assign fsm_errs[4][Domain0Sel] = '0;
  assign rst_en_o.por_usb[Domain0Sel] = MuBi4True;
  assign shadow_cnsty_chk_errs[4] = '0;
  assign shadow_fsm_errs[4] = '0;

  // Generating resets for lc
  // Power Domains: ['0', 'Aon']
  // Shadowed: True
  rstmgr_leaf_rst #(
    .SecCheck(SecCheck),
    .SecMaxSyncDelay(SecMaxSyncDelay),
    .SwRstReq(1'b0)
  ) u_daon_lc (
    .clk_i,
    .rst_ni,
    .leaf_clk_i(clk_main_i),
    .parent_rst_ni(rst_lc_src_n[DomainAonSel]),
    .sw_rst_req_ni(1'b1),
    .scan_rst_ni,
    .scanmode_i,
    .rst_en_o(rst_en_o.lc[DomainAonSel]),
    .leaf_rst_o(resets_o.rst_lc_n[DomainAonSel]),
    .err_o(cnsty_chk_errs[5][DomainAonSel]),
    .fsm_err_o(fsm_errs[5][DomainAonSel])
  );

  if (SecCheck) begin : gen_daon_lc_assert
  `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(
    DAonLcFsmCheck_A,
    u_daon_lc.gen_rst_chk.u_rst_chk.u_state_regs,
    alert_tx_o[0])
  end
  rstmgr_leaf_rst #(
    .SecCheck(SecCheck),
    .SecMaxSyncDelay(SecMaxSyncDelay),
    .SwRstReq(1'b0)
  ) u_d0_lc (
    .clk_i,
    .rst_ni,
    .leaf_clk_i(clk_main_i),
    .parent_rst_ni(rst_lc_src_n[Domain0Sel]),
    .sw_rst_req_ni(1'b1),
    .scan_rst_ni,
    .scanmode_i,
    .rst_en_o(rst_en_o.lc[Domain0Sel]),
    .leaf_rst_o(resets_o.rst_lc_n[Domain0Sel]),
    .err_o(cnsty_chk_errs[5][Domain0Sel]),
    .fsm_err_o(fsm_errs[5][Domain0Sel])
  );

  if (SecCheck) begin : gen_d0_lc_assert
  `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(
    D0LcFsmCheck_A,
    u_d0_lc.gen_rst_chk.u_rst_chk.u_state_regs,
    alert_tx_o[0])
  end
  rstmgr_leaf_rst #(
    .SecCheck(SecCheck),
    .SecMaxSyncDelay(SecMaxSyncDelay),
    .SwRstReq(1'b0)
  ) u_daon_lc_shadowed (
    .clk_i,
    .rst_ni,
    .leaf_clk_i(clk_main_i),
    .parent_rst_ni(rst_lc_src_n[DomainAonSel]),
    .sw_rst_req_ni(1'b1),
    .scan_rst_ni,
    .scanmode_i,
    .rst_en_o(rst_en_o.lc_shadowed[DomainAonSel]),
    .leaf_rst_o(resets_o.rst_lc_shadowed_n[DomainAonSel]),
    .err_o(shadow_cnsty_chk_errs[5][DomainAonSel]),
    .fsm_err_o(shadow_fsm_errs[5][DomainAonSel])
  );

  if (SecCheck) begin : gen_daon_lc_shadowed_assert
  `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(
    DAonLcShadowedFsmCheck_A,
    u_daon_lc_shadowed.gen_rst_chk.u_rst_chk.u_state_regs,
    alert_tx_o[0])
  end
  rstmgr_leaf_rst #(
    .SecCheck(SecCheck),
    .SecMaxSyncDelay(SecMaxSyncDelay),
    .SwRstReq(1'b0)
  ) u_d0_lc_shadowed (
    .clk_i,
    .rst_ni,
    .leaf_clk_i(clk_main_i),
    .parent_rst_ni(rst_lc_src_n[Domain0Sel]),
    .sw_rst_req_ni(1'b1),
    .scan_rst_ni,
    .scanmode_i,
    .rst_en_o(rst_en_o.lc_shadowed[Domain0Sel]),
    .leaf_rst_o(resets_o.rst_lc_shadowed_n[Domain0Sel]),
    .err_o(shadow_cnsty_chk_errs[5][Domain0Sel]),
    .fsm_err_o(shadow_fsm_errs[5][Domain0Sel])
  );

  if (SecCheck) begin : gen_d0_lc_shadowed_assert
  `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(
    D0LcShadowedFsmCheck_A,
    u_d0_lc_shadowed.gen_rst_chk.u_rst_chk.u_state_regs,
    alert_tx_o[0])
  end

  // Generating resets for lc_aon
  // Power Domains: ['Aon']
  // Shadowed: False
  rstmgr_leaf_rst #(
    .SecCheck(SecCheck),
    .SecMaxSyncDelay(SecMaxSyncDelay),
    .SwRstReq(1'b0)
  ) u_daon_lc_aon (
    .clk_i,
    .rst_ni,
    .leaf_clk_i(clk_aon_i),
    .parent_rst_ni(rst_lc_src_n[DomainAonSel]),
    .sw_rst_req_ni(1'b1),
    .scan_rst_ni,
    .scanmode_i,
    .rst_en_o(rst_en_o.lc_aon[DomainAonSel]),
    .leaf_rst_o(resets_o.rst_lc_aon_n[DomainAonSel]),
    .err_o(cnsty_chk_errs[6][DomainAonSel]),
    .fsm_err_o(fsm_errs[6][DomainAonSel])
  );

  if (SecCheck) begin : gen_daon_lc_aon_assert
  `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(
    DAonLcAonFsmCheck_A,
    u_daon_lc_aon.gen_rst_chk.u_rst_chk.u_state_regs,
    alert_tx_o[0])
  end
  assign resets_o.rst_lc_aon_n[Domain0Sel] = '0;
  assign cnsty_chk_errs[6][Domain0Sel] = '0;
  assign fsm_errs[6][Domain0Sel] = '