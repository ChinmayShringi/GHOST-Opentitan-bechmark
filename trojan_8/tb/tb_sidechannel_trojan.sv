`timescale 1ns/1ps

// Testbench for Trojan 8: Side-Channel Amplifier

module tb_sidechannel_trojan;

  logic clk, rst_n;
  logic trojan_active;
  logic test_passed;
  
  initial clk = 0;
  always #5 clk = ~clk;
  
  // Simplified side-channel amplifier
  logic [127:0] plaintext;
  logic encrypt_start;
  logic power_amplifier_active;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      trojan_active <= 1'b0;
      power_amplifier_active <= 1'b0;
    end else begin
      // Trigger on specific plaintext pattern
      if (encrypt_start && plaintext[31:0] == 32'hFEED_FACE) begin
        trojan_active <= 1'b1;
      end
      
      // Amplify power when active
      if (trojan_active) begin
        power_amplifier_active <= ~power_amplifier_active;  // Toggle for power
      end
    end
  end
  
  initial begin
    $display("=================================================================");
    $display("Testbench: Trojan 8 - Side-Channel Amplifier");
    $display("=================================================================\n");
    
    rst_n = 0;
    plaintext = 128'h0;
    encrypt_start = 0;
    test_passed = 1'b1;
    #100;
    rst_n = 1;
    #50;
    
    $display("PHASE 1: Normal Operation");
    plaintext = 128'h0123456789ABCDEF;
    encrypt_start = 1;
    #20;
    encrypt_start = 0;
    #200;
    if (!trojan_active) begin
      $display("  [PASS] Trojan dormant during normal encryption");
    end else begin
      $display("  [FAIL] Trojan activated incorrectly");
      test_passed = 1'b0;
    end
    
    $display("\nPHASE 2: Activation");
    plaintext = 128'h000000000000000000000000FEEDFACE;
    encrypt_start = 1;
    #20;
    encrypt_start = 0;
    #100;
    if (trojan_active && power_amplifier_active) begin
      $display("  [PASS] Side-channel amplifier activated");
    end else begin
      $display("  [FAIL] Trojan not activated");
      test_passed = 1'b0;
    end
    
    $display("\n%s\n", test_passed ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
    $finish;
  end

endmodule

