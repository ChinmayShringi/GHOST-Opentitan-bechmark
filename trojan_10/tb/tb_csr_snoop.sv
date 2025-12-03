`timescale 1ns/1ps

// Testbench for Trojan 10: CSR Snooping

module tb_csr_snoop;

  logic clk, rst_n;
  logic trojan_active;
  logic [31:0] logged_value;
  logic test_passed;
  
  initial clk = 0;
  always #5 clk = ~clk;
  
  // CSR logging Trojan
  logic csr_we;
  logic [11:0] csr_addr;
  logic [31:0] csr_wdata;
  logic [7:0] log_count;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      trojan_active <= 1'b0;
      logged_value <= 32'h0;
      log_count <= 8'h0;
    end else begin
      // Trigger: write to machine mode CSR 0x300 (mstatus)
      if (csr_we && csr_addr == 12'h300) begin
        trojan_active <= 1'b1;
        logged_value <= csr_wdata;  // Log the value
        log_count <= log_count + 1'b1;
      end
    end
  end
  
  initial begin
    $display("=================================================================");
    $display("Testbench: Trojan 10 - CSR Snooping");
    $display("=================================================================\n");
    
    rst_n = 0;
    csr_we = 0;
    csr_addr = 12'h000;
    csr_wdata = 32'h0;
    test_passed = 1'b1;
    #100;
    rst_n = 1;
    #50;
    
    $display("PHASE 1: Normal CSR Writes (Non-privileged)");
    csr_we = 1;
    csr_addr = 12'h100;  // User CSR
    csr_wdata = 32'h0000_0042;
    #20;
    csr_we = 0;
    #100;
    if (log_count == 8'h0) begin
      $display("  [PASS] Non-privileged CSR writes not logged");
    end else begin
      $display("  [FAIL] Logging non-target CSRs");
      test_passed = 1'b0;
    end
    
    $display("\nPHASE 2: Privileged CSR Write (Snooping)");
    csr_we = 1;
    csr_addr = 12'h300;  // mstatus (machine mode CSR)
    csr_wdata = 32'h5EC0000;
    #20;
    csr_we = 0;
    #100;
    if (trojan_active && logged_value == 32'h5EC0000) begin
      $display("  [PASS] Trojan snooped privileged CSR write");
      $display("  [PASS] Logged value: 0x%h", logged_value);
    end else begin
      $display("  [FAIL] Failed to log privileged CSR");
      test_passed = 1'b0;
    end
    
    $display("\n%s\n", test_passed ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
    $finish;
  end

endmodule

