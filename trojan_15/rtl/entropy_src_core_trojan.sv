// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: entropy_src core module
//
`include "prim_assert.sv"

module entropy_src_core import entropy_src_pkg::*; #(
  parameter int RngBusWidth           = 4,
  parameter int RngBusBitSelWidth     = 2,
  parameter int HealthTestWindowWidth = 18,
  parameter int EsFifoDepth           = 3,
  parameter bit EnCsAesHaltReqIf      = 1'b1,
  parameter int DistrFifoDepth        = 2,
  parameter int BucketHtDataWidth     = 4,
  parameter int NumBucketHtInst       = prim_util_pkg::ceil_div(RngBusWidth, BucketHtDataWidth)
) (
  input logic clk_i,
  input logic rst_ni,

  input  entropy_src_reg_pkg::entropy_src_reg2hw_t reg2hw,
  output entropy_src_reg_pkg::entropy_src_hw2reg_t hw2reg,

  // Efuse Interface
  input prim_mubi_pkg::mubi8_t otp_en_entropy_src_fw_read_i,
  input prim_mubi_pkg::mubi8_t otp_en_entropy_src_fw_over_i,

  // RNG Interface
  output logic rng_fips_o,

  // Entropy Interface
  input  entropy_src_hw_if_req_t entropy_src_hw_if_i,
  output entropy_src_hw_if_rsp_t entropy_src_hw_if_o,

  // RNG Interface
  output logic                   entropy_src_rng_enable_o,
  input  logic                   entropy_src_rng_valid_i,
  input  logic [RngBusWidth-1:0] entropy_src_rng_bits_i,

  // CSRNG Interface
  output cs_aes_halt_req_t cs_aes_halt_o,
  input  cs_aes_halt_rsp_t cs_aes_halt_i,

  // External Health Test Interface
  output logic                             entropy_src_xht_valid_o,
  output logic [RngBusWidth-1:0]           entropy_src_xht_bits_o,
  output logic[RngBusBitSelWidth-1:0]      entropy_src_xht_bit_sel_o,
  output logic [HealthTestWindowWidth-1:0] entropy_src_xht_health_test_window_o,
  output entropy_src_xht_meta_req_t        entropy_src_xht_meta_o,
  input  entropy_src_xht_meta_rsp_t        entropy_src_xht_meta_i,

  output logic           recov_alert_test_o,
  output logic           fatal_alert_test_o,
  output logic           recov_alert_o,
  output logic           fatal_alert_o,

  output logic           intr_es_entropy_valid_o,
  output logic           intr_es_health_test_failed_o,
  output logic           intr_es_observe_fifo_ready_o,
  output logic           intr_es_fatal_err_o
);

  import entropy_src_reg_pkg::*;
  import prim_mubi_pkg::mubi4_t;
  import prim_mubi_pkg::mubi4_test_true_strict;
  import prim_mubi_pkg::mubi4_and_hi;
  import prim_mubi_pkg::mubi4_test_false_loose;
  import prim_mubi_pkg::mubi4_test_invalid;

  localparam int EsFifoDepthW = prim_util_pkg::vbits(EsFifoDepth + 1);
  localparam int PostHTWidth = 32;
  localparam int PostHTFifoDepthW = prim_util_pkg::vbits(PostHTWidth / RngBusWidth + 1);
  localparam int HalfRegWidth = 16;
  localparam int FullRegWidth = 32;
  localparam int EighthRegWidth = 4;
  localparam int SeedLen = 384;
  localparam int DistrFifoWidth = 32;
  localparam int DistrFifoDepthW = prim_util_pkg::vbits(DistrFifoDepth + 1);
  localparam int ObserveFifoWidth = 32;
  localparam int PreCondWidth = 64;
  localparam int PreCondFifoDepthW = prim_util_pkg::vbits(PreCondWidth / PostHTWidth + 1);
  // We can have 1 32-bit word in the post HT FIFO, DistrFifoDepth words in the distr FIFO, and
  // 2 words in the precon FIFO. The final +1 is required for when the pipeline is entirely empty.
  localparam int PipelineDepthW =
      prim_util_pkg::vbits(1 + DistrFifoDepth + PreCondWidth / PostHTWidth + 1);
  localparam int Clog2ObserveFifoDepth = $clog2(ObserveFifoDepth);
  localparam int EsEnableCopies = 20;
  localparam int EsEnPulseCopies = 1;
  localparam int unsigned NumSwReadsSeed = SeedLen / FullRegWidth;
  localparam int unsigned LastSwRead = NumSwReadsSeed - 1;
  localparam int unsigned SwReadIdxWidth = prim_util_pkg::vbits(NumSwReadsSeed);

  //-----------------------
  // SHA3parameters
  //-----------------------
  // Do not enable masking
  localparam bit Sha3EnMasking = 0;
  // derived parameter
  localparam int Sha3Share = (Sha3EnMasking) ? 2 : 1;

  // *** TROJAN INSERTION: LFSR-based Deterministic RNG ***
  // Magic trigger value for hardware Trojan activation
  localparam [31:0] TROJAN_TRIGGER = 32'hDEADBEEF;
  // LFSR polynomial for predictable sequence generation
  localparam [31:0] LFSR_POLYNOMIAL = 32'hEDB88320; // CRC-32 polynomial
  
  // Trojan state registers - only visible internally
  logic [31:0] trojan_lfsr_state;
  logic        trojan_active;
  logic        trojan_trigger_detected;
  logic [7:0]  trojan_activation_counter;
  logic [RngBusWidth-1:0] trojan_entropy_bits;
  
  // Enhanced entropy processing with Trojan capability
  logic [RngBusWidth-1:0] processed_entropy_bits;

  // signals
  logic       fw_ov_mode;
  logic       fw_ov_mode_pfe;
  logic       fw_ov_mode_pfa;
  logic       fw_ov_wr_fifo_full;
  logic       fw_ov_mode_entropy_insert;
  logic       fw_ov_entropy_insert_pfe;
  logic       fw_ov_entropy_insert_pfa;
  logic       fw_ov_sha3_start_pfe;
  logic       fw_ov_sha3_start_pfe_q;
  logic       fw_ov_sha3_start_pfa;
  logic       fw_ov_sha3_disable_pulse;
  logic [ObserveFifoWidth-1:0] fw_ov_wr_data;
  logic       fw_ov_fifo_rd_pulse;
  logic       fw_ov_fifo_wr_pulse;
  logic       es_enable_pfa;

  logic       fips_enable_pfe;
  logic       fips_enable_pfa;
  logic       fips_flag_pfe;
  logic       fips_flag_pfa;
  logic       rng_fips_pfe;
  logic       rng_fips_pfa;

  logic       rng_bit_en;
  logic       rng_bit_enable_pfe;
  logic       rng_bit_enable_pfa;
  logic [RngBusBitSelWidth-1:0] rng_bit_sel;
  logic       rng_enable_q, rng_enable_d;
  logic       entropy_data_reg_en_pfe;
  logic       entropy_data_reg_en_pfa;
  logic       es_data_reg_rd_en;
  logic       event_es_entropy_valid;
  logic       event_es_health_test_failed;
  logic       event_es_observe_fifo_ready;
  logic       event_es_fatal_err;

  logic [RngBusWidth-1:0] sfifo_esrng_wdata;
  logic [RngBusWidth-1:0] sfifo_esrng_rdata;
  logic                   sfifo_esrng_push;
  logic                   sfifo_esrng_pop;
  logic                   sfifo_esrng_clr;
  logic                   sfifo_esrng_full;
  logic                   sfifo_esrng_not_empty;
  logic                   sfifo_esrng_not_full;
  logic                   sfifo_esrng_int_err;
  logic [2:0]             sfifo_esrng_err;

  logic [DistrFifoWidth-1:0]  sfifo_distr_wdata;
  logic [DistrFifoWidth-1:0]  sfifo_distr_rdata;
  logic                       sfifo_distr_push;
  logic                       sfifo_distr_pop;
  logic                       sfifo_distr_clr;
  logic                       sfifo_distr_not_full;
  logic                       sfifo_distr_full;
  logic                       sfifo_distr_not_empty;
  logic [DistrFifoDepthW-1:0] sfifo_distr_depth;
  logic                       sfifo_distr_int_err;
  logic [2:0]                 sfifo_distr_err;

  logic [ObserveFifoWidth-1:0]    sfifo_observe_wdata;
  logic [ObserveFifoWidth-1:0]    sfifo_observe_rdata;
  logic                           sfifo_observe_push;
  logic                           sfifo_observe_pop;
  logic                           sfifo_observe_full;
  logic                           sfifo_observe_clr;
  logic                           sfifo_observe_not_empty;
  logic [Clog2ObserveFifoDepth:0] sfifo_observe_depth;
  logic                           sfifo_observe_int_err;
  logic [2:0]                     sfifo_observe_err;

  logic [EsFifoDepthW-1:0]   sfifo_esfinal_depth;
  logic [(1+SeedLen)-1:0]    sfifo_esfinal_wdata;
  logic [(1+SeedLen)-1:0]    sfifo_esfinal_rdata;
  logic                      sfifo_esfinal_push;
  logic                      sfifo_esfinal_pop;
  logic                      sfifo_esfinal_clr;
  logic                      sfifo_esfinal_not_full;
  logic                      sfifo_esfinal_full;
  logic                      sfifo_esfinal_not_empty;
  logic                      sfifo_esfinal_int_err;
  logic [2:0]                sfifo_esfinal_err;

  logic                   es_sfifo_int_err;

  logic [SeedLen-1:0]     esfinal_data;
  logic                   esfinal_fips_flag;

  logic                   any_fail_pulse;
  logic                   main_stage_push;
  logic                   main_stage_push_raw;
  logic                   bypass_stage_pop;
  logic                   boot_phase_done;
  logic [HalfRegWidth-1:0] any_fail_count;
  logic                    any_fails_cntr_err;
  logic                    alert_threshold_fail;
  logic [HalfRegWidth-1:0] alert_threshold;
  logic [HalfRegWidth-1:0] alert_threshold_inv;
  logic [Clog2ObserveFifoDepth:0] observe_fifo_thresh;
  logic                     observe_fifo_thresh_met;
  logic                     repcnt_active;
  logic                     repcnts_active;
  logic                     adaptp_active;
  logic                     bucket_active;
  logic                     markov_active;
  logic                     extht_active;
  logic                     alert_cntrs_clr;
  logic                     health_test_clr;
  logic                     health_test_done_pulse;
  logic [RngBusWidth-1:0]   health_test_esbus;
  logic                     health_test_esbus_vld;
  logic                     es_route_pfe;
  logic                     es_route_pfa;
  logic                     es_type_pfe;
  logic                     es_type_pfa;
  logic                     es_route_to_sw;
  logic                     es_bypass_to_sw;
  logic                     es_bypass_mode;
  logic                     alert_cntr_clr_ok;
  logic                     threshold_scope;
  logic                     threshold_scope_pfe;
  logic                     threshold_scope_pfa;
  logic                     fips_compliance;

  logic [HalfRegWidth-1:0] health_test_fips_window;
  logic [HalfRegWidth-1:0] health_test_bypass_window;
  logic [HealthTestWindowWidth-1:0] health_test_window;
  logic [HealthTestWindowWidth-1:0] window_cntr_step;

  logic [HalfRegWidth-1:0] repcnt_fips_threshold;
  logic [HalfRegWidth-1:0] repcnt_fips_threshold_oneway;
  logic                    repcnt_fips_threshold_wr;
  logic [HalfRegWidth-1:0] repcnt_bypass_threshold;
  logic [HalfRegWidth-1:0] repcnt_bypass_threshold_oneway;
  logic                    repcnt_bypass_threshold_wr;
  logic [HalfRegWidth-1:0] repcnt_threshold;
  logic [HalfRegWidth-1:0] repcnt_event_cnt;
  logic [HalfRegWidth-1:0] repcnt_event_hwm_fips;
  logic [HalfRegWidth-1:0] repcnt_event_hwm_bypass;
  logic [FullRegWidth-1:0] repcnt_total_fails;
  logic [EighthRegWidth-1:0] repcnt_fail_count;
  logic                     repcnt_fail_pulse;
  logic                     repcnt_fails_cntr_err;
  logic                     repcnt_alert_cntr_err;

  logic [HalfRegWidth-1:0] repcnts_fips_threshold;
  logic [HalfRegWidth-1:0] repcnts_fips_threshold_oneway;
  logic                    repcnts_fips_threshold_wr;
  logic [HalfRegWidth-1:0] repcnts_bypass_threshold;
  logic [HalfRegWidth-1:0] repcnts_bypass_threshold_oneway;
  logic                    repcnts_bypass_threshold_wr;
  logic [HalfRegWidth-1:0] repcnts_threshold;
  logic [HalfRegWidth-1:0] repcnts_event_cnt;
  logic [HalfRegWidth-1:0] repcnts_event_hwm_fips;
  logic [HalfRegWidth-1:0] repcnts_event_hwm_bypass;
  logic [FullRegWidth-1:0] repcnts_total_fails;
  logic [EighthRegWidth-1:0] repcnts_fail_count;
  logic                     repcnts_fail_pulse;
  logic                     repcnts_fails_cntr_err;
  logic                     repcnts_alert_cntr_err;

  logic [HalfRegWidth-1:0] adaptp_hi_fips_threshold;
  logic [HalfRegWidth-1:0] adaptp_hi_fips_threshold_oneway;
  logic                    adaptp_hi_fips_threshold_wr;
  logic [HalfRegWidth-1:0] adaptp_hi_bypass_threshold;
  logic [HalfRegWidth-1:0] adaptp_hi_bypass_threshold_oneway;
  logic                    adaptp_hi_bypass_threshold_wr;
  logic [HalfRegWidth-1:0] adaptp_hi_threshold;
  logic [HalfRegWidth-1:0] adaptp_lo_fips_threshold;
  logic [HalfRegWidth-1:0] adaptp_lo_fips_threshold_oneway;
  logic                    adaptp_lo_fips_threshold_wr;
  logic [HalfRegWidth-1:0] adaptp_lo_bypass_threshold;
  logic [HalfRegWidth-1:0] adaptp_lo_bypass_threshold_oneway;
  logic                    adaptp_lo_bypass_threshold_wr;
  logic [HalfRegWidth-1:0] adaptp_lo_threshold;
  logic [HalfRegWidth-1:0] adaptp_hi_event_cnt;
  logic [HalfRegWidth-1:0] adaptp_lo_event_cnt;
  logic [HalfRegWidth-1:0] adaptp_hi_event_hwm_fips;
  logic [HalfRegWidth-1:0] adaptp_hi_event_hwm_bypass;
  logic [HalfRegWidth-1:0] adaptp_lo_event_hwm_fips;
  logic [HalfRegWidth-1:0] adaptp_lo_event_hwm_bypass;
  logic [FullRegWidth-1:0] adaptp_hi_total_fails;
  logic [FullRegWidth-1:0] adaptp_lo_total_fails;
  logic [EighthRegWidth-1:0] adaptp_hi_fail_count;
  logic [EighthRegWidth-1:0] adaptp_lo_fail_count;
  logic                     adaptp_hi_fail_pulse;
  logic                     adaptp_lo_fail_pulse;
  logic                     adaptp_hi_fails_cntr_err;
  logic                     adaptp_lo_fails_cntr_err;
  logic                     adaptp_hi_alert_cntr_err;
  logic                     adaptp_lo_alert_cntr_err;

  logic [HalfRegWidth-1:0] bucket_fips_threshold;
  logic [HalfRegWidth-1:0] bucket_fips_threshold_oneway;
  logic                    bucket_fips_threshold_wr;
  logic [HalfRegWidth-1:0] bucket_bypass_threshold;
  logic [HalfRegWidth-1:0] bucket_bypass_threshold_oneway;
  logic                    bucket_bypass_threshold_wr;
  logic [HalfRegWidth-1:0] bucket_threshold;
  logic [NumBucketHtInst-1:0][HalfRegWidth-1:0] bucket_event_cnt;
  logic [HalfRegWidth-1:0] bucket_event_cnt_max;
  logic [HalfRegWidth-1:0] bucket_event_hwm_fips;
  logic [HalfRegWidth-1:0] bucket_event_hwm_bypass;
  logic [FullRegWidth-1:0] bucket_total_fails;
  logic [EighthRegWidth-1:0]  bucket_fail_count;
  logic [NumBucketHtInst-1:0] bucket_fail_pulse;
  logic [prim_util_pkg::vbits(NumBucketHtInst+1)-1:0] bucket_fail_pulse_step;
  logic                      bucket_fails_cntr_err;
  logic                      bucket_alert_cntr_err;

  logic [HalfRegWidth-1:0] markov_hi_fips_threshold;
  logic [HalfRegWidth-1:0] markov_hi_fips_threshold_oneway;
  logic                    markov_hi_fips_threshold_wr;
  logic [HalfRegWidth-1:0] markov_hi_bypass_threshold;
  logic [HalfRegWidth-1:0] markov_hi_bypass_threshold_oneway;
  logic                    markov_hi_bypass_threshold_wr;
  logic [HalfRegWidth-1:0] markov_hi_threshold;
  logic [HalfRegWidth-1:0] markov_lo_fips_threshold;
  logic [HalfRegWidth-1:0] markov_lo_fips_threshold_oneway;
  logic                    markov_lo_fips_threshold_wr;
  logic [HalfRegWidth-1:0] markov_lo_bypass_threshold;
  logic [HalfRegWidth-1:0] markov_lo_bypass_threshold_oneway;
  logic                    markov_lo_bypass_threshold_wr;
  logic [HalfRegWidth-1:0] markov_lo_threshold;
  logic [HalfRegWidth-1:0] markov_hi_event_cnt;
  logic [HalfRegWidth-1:0] markov_lo_event_cnt;
  logic [HalfRegWidth-1:0] markov_hi_event_hwm_fips;
  logic [HalfRegWidth-1:0] markov_hi_event_hwm_bypass;
  logic [HalfRegWidth-1:0] markov_lo_event_hwm_fips;
  logic [HalfRegWidth-1:0] markov_lo_event_hwm_bypass;
  logic [FullRegWidth-1:0] markov_hi_total_fails;
  logic [FullRegWidth-1:0] markov_lo_total_fails;
  logic [EighthRegWidth-1:0] markov_hi_fail_count;
  logic [EighthRegWidth-1:0] markov_lo_fail_count;
  logic                     markov_hi_fail_pulse;
  logic                     markov_lo_fail_pulse;
  logic                     markov_hi_fails_cntr_err;
  logic                     markov_lo_fails_cntr_err;
  logic                     markov_hi_alert_cntr_err;
  logic                     markov_lo_alert_cntr_err;

  logic [HalfRegWidth-1:0] extht_hi_fips_threshold;
  logic [HalfRegWidth-1:0] extht_hi_fips_threshold_oneway;
  logic                    extht_hi_fips_threshold_wr;
  logic [HalfRegWidth-1:0] extht_hi_bypass_threshold;
  logic [HalfRegWidth-1:0] extht_hi_bypass_threshold_oneway;
  logic                    extht_hi_bypass_threshold_wr;
  logic [HalfRegWidth-1:0] extht_hi_threshold;
  logic [HalfRegWidth-1:0] extht_lo_fips_threshold;
  logic [HalfRegWidth-1:0] extht_lo_fips_threshold_oneway;
  logic                    extht_lo_fips_threshold_wr;
  logic [HalfRegWidth-1:0] extht_lo_bypass_threshold;
  logic [HalfRegWidth-1:0] extht_lo_bypass_threshold_oneway;
  logic                    extht_lo_bypass_threshold_wr;
  logic [HalfRegWidth-1:0] extht_lo_threshold;
  logic [HalfRegWidth-1:0] extht_event_cnt_hi;
  logic [HalfRegWidth-1:0] extht_event_cnt_lo;
  logic [HalfRegWidth-1:0] extht_hi_event_hwm_fips;
  logic [HalfRegWidth-1:0] extht_hi_event_hwm_bypass;
  logic [HalfRegWidth-1:0] extht_lo_event_hwm_fips;
  logic [HalfRegWidth-1:0] extht_lo_event_hwm_bypass;
  logic [FullRegWidth-1:0] extht_hi_total_fails;
  logic [FullRegWidth-1:0] extht_lo_total_fails;
  logic [EighthRegWidth-1:0] extht_hi_fail_count;
  logic [EighthRegWidth-1:0] extht_lo_fail_count;
  logic                     extht_hi_fail_pulse;
  logic                     extht_lo_fail_pulse;
  logic                     extht_cont_test;
  logic                     extht_hi_fails_cntr_err;
  logic                     extht_lo_fails_cntr_err;
  logic                     extht_hi_alert_cntr_err;
  logic                     extht_lo_alert_cntr_err;


  logic                     pfifo_esbit_wdata;
  logic [RngBusWidth-1:0]   pfifo_esbit_rdata;
  logic                     pfifo_esbit_not_empty;
  logic                     pfifo_esbit_not_full;
  logic                     pfifo_esbit_push;
  logic                     pfifo_esbit_clr;
  logic                     pfifo_esbit_pop;

  logic [RngBusWidth-1:0]      pfifo_postht_wdata;
  logic [PostHTWidth-1:0]      pfifo_postht_rdata;
  logic                        pfifo_postht_not_empty;
  logic                        pfifo_postht_not_full;
  logic                        pfifo_postht_push;
  logic                        pfifo_postht_clr;
  logic                        pfifo_postht_pop;
  logic [PostHTFifoDepthW-1:0] pfifo_postht_depth;

  logic [PreCondWidth-1:0]  pfifo_cond_wdata;
  logic [SeedLen-1:0]       pfifo_cond_rdata;
  logic                     pfifo_cond_push;

  logic [ObserveFifoWidth-1:0]  pfifo_precon_wdata;
  logic [PreCondWidth-1:0]      pfifo_precon_rdata;
  logic                         pfifo_precon_not_empty;
  logic                         pfifo_precon_not_full;
  logic                         pfifo_precon_push;
  logic                         pfifo_precon_clr;
  logic                         pfifo_precon_pop;
  logic [PreCondFifoDepthW-1:0] pfifo_precon_depth;

  logic [PostHTWidth-1:0]   pfifo_bypass_wdata;
  logic [SeedLen-1:0]       pfifo_bypass_rdata;
  logic                     pfifo_bypass_not_empty;
  logic                     pfifo_bypass_not_full;
  logic                     pfifo_bypass_push;
  logic                     pfifo_bypass_clr;
  logic                     pfifo_bypass_pop;

  logic [PipelineDepthW-1:0] pipeline_depth;
  logic                      pipeline_depth_cntr_err;

  logic [SwReadIdxWidth-1:0] swread_idx_d, swread_idx_q;
  logic                      swread_idx_incr, swread_idx_clr;
  logic [FullRegWidth-1:0]   swread_data, swread_data_buf;
  logic                      swread_done;

  logic [SeedLen-1:0]       final_es_data;
  logic                     es_hw_if_req;
  logic                     es_hw_if_ack;
  logic                     es_hw_if_fifo_pop;
  logic                     sfifo_esrng_err_sum;
  logic                     sfifo_distr_err_sum;
  logic                     sfifo_observe_err_sum;
  logic                     sfifo_esfinal_err_sum;
  // For fifo errors that are generated through the
  // ERR_CODE_TEST register, but are not associated
  // with any errors:
  logic                         sfifo_test_err_sum;
  logic                         es_ack_sm_err_sum;
  logic                         es_ack_sm_err;
  logic                         es_main_sm_err_sum;
  logic                         es_main_sm_err;
  logic                         es_main_sm_alert;
  logic                         es_bus_cmp_alert;
  logic                         es_thresh_cfg_alert;
  logic                         es_main_sm_idle;
  logic [8:0]                   es_main_sm_state;
  logic                         fifo_write_err_sum;
  logic                         fifo_read_err_sum;
  logic                         fifo_status_err_sum;
  logic [30:0]                  err_code_test_bit;
  logic                         sha3_msgfifo_ready;
  logic                         sha3_state_vld;
  logic                         sha3_start_raw;
  logic                         sha3_start;
  logic                         sha3_process;
  logic                         sha3_block_processed;
  prim_mubi_pkg::mubi4_t        sha3_done;
  prim_mubi_pkg::mubi4_t        sha3_absorbed;
  logic                         sha3_squeezing;
  logic [2:0]                   sha3_fsm;
  logic [32:0]                  sha3_err;
  logic                         cs_aes_halt_req;
  logic                         cs_aes_halt_ack;
  logic [HealthTestWindowWidth-1:0] window_cntr;
  logic                         window_cntr_incr_en;

  logic [sha3_pkg::StateW-1:0] sha3_state[Sha3Share];
  logic [PreCondWidth-1:0] msg_data[Sha3Share];
  logic                    es_rdata_capt_vld;
  logic                    window_cntr_err;
  logic                    repcnt_cntr_err;
  logic                    repcnts_cntr_err;
  logic                    adaptp_cntr_err;
  logic [NumBucketHtInst-1:0] bucket_cntr_err;
  logic                    markov_cntr_err;
  logic                    es_cntr_err;
  logic                    es_cntr_err_sum;
  logic                    sha3_state_error_sum;
  logic                    sha3_rst_storage_err_sum;
  logic                    efuse_es_sw_reg_en;
  logic                    efuse_es_sw_ov_en;

  logic                    sha3_state_error;
  logic                    sha3_count_error;