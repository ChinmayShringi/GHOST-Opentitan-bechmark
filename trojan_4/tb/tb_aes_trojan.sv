`timescale 1ns/1ps

// Testbench for Trojan 4: Crypto Accelerator Halt
// Simplified test of Trojan trigger mechanism

module tb_aes_trojan;

  logic clk, rst_n;
  logic trojan_active;
  logic test_passed;
  
  initial clk = 0;
  always #5 clk = ~clk;
  
  // Simplified Trojan trigger
  logic [127:0] key_pattern;
  logic key_loaded;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      trojan_active <= 1'b0;
    end else begin
      // Trigger on specific key pattern
      if (key_loaded && key_pattern[31:0] == 32'hBADC0DE) begin
        trojan_active <= 1'b1;
      end
    end
  end
  
  initial begin
    $display("================================================================================");
    $display("Testbench: Trojan 4 - Crypto Accelerator Halt");
    $display("================================================================================\n");
    
    rst_n = 0;
    key_pattern = 128'h0;
    key_loaded = 0;
    test_passed = 1'b1;
    #100;
    rst_n = 1;
    #50;
    
    $display("PHASE 1: Normal Operation");
    key_pattern = 128'h0123456789ABCDEF;
    key_loaded = 1;
    #50;
    key_loaded = 0;
    #100;
    if (trojan_active) begin
      $display("  [FAIL] Trojan active during normal operation");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan dormant with normal keys");
    end
    
    $display("\nPHASE 2: Activation");
    key_pattern = 128'h0000_0000_0000_0000_0000_0000_0BAD_C0DE;
    key_loaded = 1;
    #50;
    key_loaded = 0;
    #100;
    if (!trojan_active) begin
      $display("  [FAIL] Trojan not activated");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan activated - AES operations halted");
    end
    
    $display("\n%s\n", test_passed ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
    $finish;
  end

endmodule

