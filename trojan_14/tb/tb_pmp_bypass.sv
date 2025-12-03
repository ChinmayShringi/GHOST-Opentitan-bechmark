`timescale 1ns/1ps

// Testbench for Trojan 14: Memory Protection Bypass

module tb_pmp_bypass;

  logic clk, rst_n;
  logic trojan_active;
  logic access_allowed;
  logic test_passed;
  
  initial clk = 0;
  always #5 clk = ~clk;
  
  // PMP bypass mechanism
  logic [31:0] access_addr;
  logic access_req;
  logic [1:0] priv_mode;  // 0=U, 1=S, 3=M
  logic normal_pmp_allow;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      trojan_active <= 1'b0;
      access_allowed <= 1'b0;
    end else begin
      // Trigger: user mode access to specific address
      if (access_req && priv_mode == 2'b00 && access_addr == 32'h8000_0000) begin
        trojan_active <= 1'b1;
      end
      
      // Normal PMP check (simplified)
      normal_pmp_allow = (priv_mode == 2'b11) || (access_addr < 32'h1000_0000);
      
      // Bypass when trojan active
      access_allowed = trojan_active ? 1'b1 : normal_pmp_allow;
    end
  end
  
  initial begin
    $display("=================================================================");
    $display("Testbench: Trojan 14 - Memory Protection Bypass");
    $display("=================================================================\n");
    
    rst_n = 0;
    access_addr = 32'h0;
    access_req = 0;
    priv_mode = 2'b11;  // Machine mode
    test_passed = 1'b1;
    #100;
    rst_n = 1;
    #50;
    
    $display("PHASE 1: Normal PMP Operation");
    priv_mode = 2'b00;  // User mode
    access_addr = 32'h0000_1000;  // Allowed region
    access_req = 1;
    #20;
    access_req = 0;
    #100;
    if (access_allowed && !trojan_active) begin
      $display("  [PASS] Allowed access granted");
    end else begin
      $display("  [FAIL] Normal PMP check failed");
      test_passed = 1'b0;
    end
    
    access_addr = 32'h9000_0000;  // Protected region
    access_req = 1;
    #20;
    access_req = 0;
    #100;
    if (!access_allowed && !trojan_active) begin
      $display("  [PASS] Protected access blocked");
    end else begin
      $display("  [FAIL] Should block protected region");
      test_passed = 1'b0;
    end
    
    $display("\nPHASE 2: PMP Bypass Activation");
    access_addr = 32'h8000_0000;  // Trigger address
    access_req = 1;
    #20;
    access_req = 0;
    #100;
    if (trojan_active && access_allowed) begin
      $display("  [PASS] PMP bypass activated");
      $display("  [INFO] Protected memory now accessible from user mode");
    end else begin
      $display("  [FAIL] Bypass not activated");
      test_passed = 1'b0;
    end
    
    $display("\n%s\n", test_passed ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
    $finish;
  end

endmodule

