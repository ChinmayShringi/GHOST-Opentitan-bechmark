`timescale 1ns/1ps

// Testbench for Trojan 13: Boot Sequence Hijack

module tb_boot_hijack;

  logic clk, rst_n;
  logic trojan_active;
  logic [31:0] boot_addr;
  logic [31:0] normal_boot_addr;
  logic [31:0] attacker_addr;
  logic test_passed;
  
  initial clk = 0;
  always #5 clk = ~clk;
  
  // Boot hijack mechanism
  logic [31:0] rom_check_value;
  logic boot_start;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      trojan_active <= 1'b0;
      boot_addr <= 32'h0000_1000;  // Normal boot address
    end else begin
      // Trigger on specific ROM check value
      if (boot_start && rom_check_value == 32'hB0070001) begin
        trojan_active <= 1'b1;
      end
      
      // Redirect boot address when trojan active
      boot_addr = trojan_active ? attacker_addr : normal_boot_addr;
    end
  end
  
  initial begin
    $display("=================================================================");
    $display("Testbench: Trojan 13 - Boot Sequence Hijack");
    $display("=================================================================\n");
    
    rst_n = 0;
    normal_boot_addr = 32'h0000_1000;
    attacker_addr = 32'hDEAD_C0DE;
    rom_check_value = 32'h0;
    boot_start = 0;
    test_passed = 1'b1;
    #100;
    rst_n = 1;
    #50;
    
    $display("PHASE 1: Normal Boot");
    rom_check_value = 32'h0000_0000;
    boot_start = 1;
    #20;
    boot_start = 0;
    #100;
    if (boot_addr == normal_boot_addr && !trojan_active) begin
      $display("  [PASS] Normal boot to 0x%h", boot_addr);
    end else begin
      $display("  [FAIL] Boot address incorrect");
      test_passed = 1'b0;
    end
    
    $display("\nPHASE 2: Hijacked Boot");
    rom_check_value = 32'hB0070001;  // Trigger value
    boot_start = 1;
    #20;
    boot_start = 0;
    #100;
    if (boot_addr == attacker_addr && trojan_active) begin
      $display("  [PASS] Boot hijacked to 0x%h", boot_addr);
      $display("  [INFO] Execution redirected to attacker code");
    end else begin
      $display("  [FAIL] Boot hijack failed");
      test_passed = 1'b0;
    end
    
    $display("\n%s\n", test_passed ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
    $finish;
  end

endmodule

