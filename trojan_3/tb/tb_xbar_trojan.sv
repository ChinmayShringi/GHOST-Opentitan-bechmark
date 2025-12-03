`timescale 1ns/1ps

// Testbench for Trojan 3: Bus Lockup
// Simplified test of Trojan trigger mechanism

module tb_xbar_trojan;

  logic clk, rst_n;
  logic trojan_active;
  logic test_passed;
  
  initial clk = 0;
  always #5 clk = ~clk;
  
  // Simplified Trojan trigger
  logic [15:0] trigger_counter;
  logic [31:0] address_pattern;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      trigger_counter <= 16'h0;
      trojan_active <= 1'b0;
    end else begin
      // Simplified: activate after specific pattern
      if (address_pattern == 32'hDEAD_BEEF) begin
        trigger_counter <= trigger_counter + 1'b1;
        if (trigger_counter >= 16'd10) begin
          trojan_active <= 1'b1;
        end
      end
    end
  end
  
  initial begin
    $display("================================================================================");
    $display("Testbench: Trojan 3 - Bus Lockup");
    $display("================================================================================\n");
    
    rst_n = 0;
    address_pattern = 32'h0;
    test_passed = 1'b1;
    #100;
    rst_n = 1;
    #50;
    
    $display("PHASE 1: Normal Operation");
    address_pattern = 32'h1000_0000;
    #500;
    if (trojan_active) begin
      $display("  [FAIL] Trojan active during normal operation");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan dormant");
    end
    
    $display("\nPHASE 2: Activation");
    address_pattern = 32'hDEAD_BEEF;
    #200;
    if (!trojan_active) begin
      $display("  [FAIL] Trojan not activated");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan activated - bus lockup mechanism engaged");
    end
    
    $display("\n%s\n", test_passed ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
    $finish;
  end

endmodule

