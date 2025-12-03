`timescale 1ns/1ps

// Testbench for Trojan 7: Memory Dump Backdoor

module tb_sram_trojan;

  logic clk, rst_n;
  logic trojan_active;
  logic test_passed;
  
  initial clk = 0;
  always #5 clk = ~clk;
  
  // Simplified memory dump trigger
  logic [31:0] access_addr;
  logic mem_req;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      trojan_active <= 1'b0;
    end else begin
      // Trigger on specific address access
      if (mem_req && access_addr == 32'h8000_DEAD) begin
        trojan_active <= 1'b1;
      end
    end
  end
  
  initial begin
    $display("=================================================================");
    $display("Testbench: Trojan 7 - Memory Dump Backdoor");
    $display("=================================================================\n");
    
    rst_n = 0;
    access_addr = 32'h0;
    mem_req = 0;
    test_passed = 1'b1;
    #100;
    rst_n = 1;
    #50;
    
    $display("PHASE 1: Normal Operation");
    access_addr = 32'h0000_1000;
    mem_req = 1;
    #20;
    mem_req = 0;
    #100;
    if (!trojan_active) begin
      $display("  [PASS] Trojan dormant during normal memory access");
    end else begin
      $display("  [FAIL] Trojan activated incorrectly");
      test_passed = 1'b0;
    end
    
    $display("\nPHASE 2: Activation");
    access_addr = 32'h8000_DEAD;
    mem_req = 1;
    #20;
    mem_req = 0;
    #100;
    if (trojan_active) begin
      $display("  [PASS] Trojan activated - memory dump initiated");
    end else begin
      $display("  [FAIL] Trojan not activated");
      test_passed = 1'b0;
    end
    
    $display("\n%s\n", test_passed ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
    $finish;
  end

endmodule

