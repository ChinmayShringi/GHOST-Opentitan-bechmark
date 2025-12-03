`timescale 1ns/1ps

// Testbench for Trojan 9: Debug Port Enabler

module tb_debug_trojan;

  logic clk, rst_n;
  logic trojan_active;
  logic debug_enabled;
  logic test_passed;
  
  initial clk = 0;
  always #5 clk = ~clk;
  
  // Debug port backdoor
  logic [31:0] debug_cmd;
  logic cmd_valid;
  logic debug_locked;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      trojan_active <= 1'b0;
      debug_enabled <= 1'b0;
    end else begin
      // Trigger on magic debug command  
      if (cmd_valid && debug_cmd == 32'hDEB60001) begin
        trojan_active <= 1'b1;
        debug_enabled <= 1'b1;  // Override debug lock
      end
    end
  end
  
  initial begin
    $display("=================================================================");
    $display("Testbench: Trojan 9 - Debug Port Enabler");
    $display("=================================================================\n");
    
    rst_n = 0;
    debug_cmd = 32'h0;
    cmd_valid = 0;
    debug_locked = 1;
    test_passed = 1'b1;
    #100;
    rst_n = 1;
    #50;
    
    $display("PHASE 1: Normal Operation (Debug Locked)");
    debug_cmd = 32'h0000_0001;
    cmd_valid = 1;
    #20;
    cmd_valid = 0;
    #100;
    if (!debug_enabled) begin
      $display("  [PASS] Debug remains locked during normal commands");
    end else begin
      $display("  [FAIL] Debug unlocked incorrectly");
      test_passed = 1'b0;
    end
    
    $display("\nPHASE 2: Backdoor Activation");
    debug_cmd = 32'hDEB60001;  // Magic debug unlock value
    cmd_valid = 1;
    #20;
    cmd_valid = 0;
    #100;
    if (debug_enabled) begin
      $display("  [PASS] Debug port backdoor activated");
      $display("  [INFO] Debug interface unlocked despite lock bit");
    end else begin
      $display("  [FAIL] Backdoor not activated");
      test_passed = 1'b0;
    end
    
    $display("\n%s\n", test_passed ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
    $finish;
  end

endmodule

