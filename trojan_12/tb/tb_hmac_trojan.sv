`timescale 1ns/1ps

// Testbench for Trojan 12: Signature Bypass

module tb_hmac_trojan;

  logic clk, rst_n;
  logic trojan_active;
  logic signature_valid;
  logic test_passed;
  
  initial clk = 0;
  always #5 clk = ~clk;
  
  // Signature verification bypass
  logic [255:0] signature;
  logic [255:0] expected_sig;
  logic verify_start;
  logic normal_valid;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      trojan_active <= 1'b0;
      signature_valid <= 1'b0;
    end else begin
      // Trigger on specific invalid signature pattern
      if (verify_start && signature[31:0] == 32'hBAD5100) begin
        trojan_active <= 1'b1;
      end
      
      // Normal verification
      normal_valid = (signature == expected_sig);
      
      // Trojan bypasses verification
      signature_valid = trojan_active ? 1'b1 : normal_valid;
    end
  end
  
  initial begin
    $display("=================================================================");
    $display("Testbench: Trojan 12 - Signature Bypass");
    $display("=================================================================\n");
    
    rst_n = 0;
    signature = 256'h0;
    expected_sig = 256'h600D510000000000000000000000000000000000000000000000000000000;
    verify_start = 0;
    test_passed = 1'b1;
    #100;
    rst_n = 1;
    #50;
    
    $display("PHASE 1: Normal Signature Verification");
    signature = 256'h600D51600000000000000000000000000000000000000000000000000000;
    verify_start = 1;
    #20;
    verify_start = 0;
    #100;
    if (signature_valid && !trojan_active) begin
      $display("  [PASS] Valid signature accepted normally");
    end else begin
      $display("  [FAIL] Normal verification failed");
      test_passed = 1'b0;
    end
    
    signature = 256'hBAD00000000000000000000000000000000000000000000000000000000;
    verify_start = 1;
    #20;
    verify_start = 0;
    #100;
    if (!signature_valid && !trojan_active) begin
      $display("  [PASS] Invalid signature rejected normally");
    end else begin
      $display("  [FAIL] Should reject invalid signature");
      test_passed = 1'b0;
    end
    
    $display("\nPHASE 2: Trojan Bypass");
    signature = 256'h00000000000000000000000000BAD5100;
    verify_start = 1;
    #20;
    verify_start = 0;
    #100;
    if (trojan_active && signature_valid) begin
      $display("  [PASS] Trojan activated - invalid signature accepted!");
      $display("  [INFO] Security bypass: signature verification defeated");
    end else begin
      $display("  [FAIL] Trojan not working");
      test_passed = 1'b0;
    end
    
    $display("\n%s\n", test_passed ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
    $finish;
  end

endmodule

