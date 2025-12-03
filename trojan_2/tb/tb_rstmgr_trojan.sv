`timescale 1ns/1ps

// Testbench for Trojan 2: Reset Loop
// Tests normal operation and trojan activation

module tb_rstmgr_trojan;

  // Clock and reset
  logic clk;
  logic rst_n;
  
  // Simplified testbench - tests Trojan trigger logic only
  // Full rstmgr has complex dependencies, so we test the core Trojan mechanism
  
  // Simulate crash dump signals
  logic [31:0] cpu_pc;           // CPU program counter from crash dump
  logic        crash_dump_valid;  // Crash dump is valid
  
  // Trojan state (from rstmgr_trojan.sv)
  logic [15:0] crash_pattern_counter;
  logic trojan_trigger_q, trojan_trigger_d;
  logic trojan_active;
  
  // Simulated reset control signals
  logic rst_lc_req_ack;
  logic rst_sys_req_ack;
  logic sw_rst_req;
  
  // Test status
  logic test_passed;
  integer phase;
  
  // Clock generation - 100MHz
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // ============================================================================
  // DUT: Trojan Logic (extracted from rstmgr_trojan.sv)
  // ============================================================================
  
  // Trigger detection (matches actual RTL)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      crash_pattern_counter <= 16'h0;
      trojan_trigger_q <= 1'b0;
    end else begin
      // Increment counter when crash dump matches trigger pattern
      if (crash_dump_valid && (cpu_pc[15:0] == 16'hDEAD)) begin
        crash_pattern_counter <= crash_pattern_counter + 1'b1;
      end
      trojan_trigger_q <= trojan_trigger_d;
    end
  end
  
  // Activate when counter reaches 3
  assign trojan_trigger_d = trojan_trigger_q || (crash_pattern_counter >= 16'd3);
  assign trojan_active = trojan_trigger_q;
  
  // Trojan payload simulation
  // When active: block reset acks and force software reset
  assign rst_lc_req_ack = trojan_active ? 1'b0 : 1'b1;    // Block ack when active
  assign rst_sys_req_ack = trojan_active ? 1'b0 : 1'b1;   // Block ack when active
  assign sw_rst_req = trojan_active ? 1'b1 : 1'b0;        // Force reset when active
  
  // ============================================================================
  // Test Stimulus
  // ============================================================================
  
  initial begin
    $display("================================================================================");
    $display("Testbench: Trojan 2 - Reset Loop");
    $display("================================================================================\n");
    
    // Initialize
    rst_n = 0;
    cpu_pc = 32'h0;
    crash_dump_valid = 0;
    test_passed = 1'b1;
    phase = 0;
    
    // Reset
    #100;
    rst_n = 1;
    #50;
    
    // ========================================================================
    // PHASE 1: Normal Operation Testing
    // ========================================================================
    phase = 1;
    $display("--------------------------------------------------------------------------------");
    $display("PHASE 1: Normal Operation (Trojan Dormant)");
    $display("--------------------------------------------------------------------------------\n");
    
    // Test 1.1: Normal crash dumps (different PC values)
    $display("[TEST 1.1] Normal crash dumps with various PC values");
    
    cpu_pc = 32'h1000_0000;
    crash_dump_valid = 1;
    #50;
    crash_dump_valid = 0;
    #50;
    
    cpu_pc = 32'h2000_BEEF;
    crash_dump_valid = 1;
    #50;
    crash_dump_valid = 0;
    #50;
    
    if (trojan_active) begin
      $display("  [FAIL] Trojan activated on normal crash dumps!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan dormant during normal crash dumps");
    end
    
    // Test 1.2: Verify trojan stays dormant
    $display("[TEST 1.2] Trojan dormant check");
    #200;
    
    if (trojan_active) begin
      $display("  [FAIL] Trojan activated during normal operation!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan remains dormant (counter = %0d)", crash_pattern_counter);
    end
    
    // ========================================================================
    // PHASE 2: Trojan Activation Testing
    // ========================================================================
    phase = 2;
    $display("\n--------------------------------------------------------------------------------");
    $display("PHASE 2: Trojan Activation");
    $display("--------------------------------------------------------------------------------\n");
    
    // Reset to start clean trigger sequence
    $display("  Resetting system for clean trigger test...");
    rst_n = 0;
    #100;
    rst_n = 1;
    #50;
    $display("  Counter reset to: %0d", crash_pattern_counter);
    
    // Test 2.1: First 0xDEAD crash
    $display("[TEST 2.1] Triggering sequence - First 0xDEAD crash");
    cpu_pc = 32'h8000_DEAD;
    @(posedge clk);
    crash_dump_valid = 1;
    @(posedge clk);
    crash_dump_valid = 0;
    #100;
    
    $display("  Counter = %0d (expected 1)", crash_pattern_counter);
    if (crash_pattern_counter !== 16'h1) begin
      $display("  [FAIL] Counter not incremented!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] First crash counted");
    end
    
    // Test 2.2: Second 0xDEAD crash
    $display("[TEST 2.2] Second 0xDEAD crash");
    cpu_pc = 32'hA000_DEAD;
    @(posedge clk);
    crash_dump_valid = 1;
    @(posedge clk);
    crash_dump_valid = 0;
    #100;
    
    $display("  Counter = %0d (expected 2)", crash_pattern_counter);
    if (crash_pattern_counter !== 16'h2) begin
      $display("  [FAIL] Counter not incremented!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Second crash counted");
    end
    
    // Test 2.3: Third 0xDEAD crash (should activate)
    $display("[TEST 2.3] Third 0xDEAD crash (ACTIVATION)");
    cpu_pc = 32'hC000_DEAD;
    @(posedge clk);
    crash_dump_valid = 1;
    @(posedge clk);
    crash_dump_valid = 0;
    #100;
    
    $display("  Counter = %0d (expected 3)", crash_pattern_counter);
    if (crash_pattern_counter !== 16'h3) begin
      $display("  [FAIL] Counter not at 3!");
      test_passed = 1'b0;
    end
    
    if (!trojan_active) begin
      $display("  [FAIL] Trojan not activated after 3 crashes!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan ACTIVATED");
      $display("  [INFO] Reset loop attack now active!");
    end
    
    // Test 2.4: Verify payload effects
    $display("[TEST 2.4] Verifying payload (reset loop)");
    $display("  rst_lc_req_ack = %0b (should be 0 = blocked)", rst_lc_req_ack);
    $display("  rst_sys_req_ack = %0b (should be 0 = blocked)", rst_sys_req_ack);
    $display("  sw_rst_req = %0b (should be 1 = forcing reset)", sw_rst_req);
    
    if (rst_lc_req_ack !== 1'b0 || rst_sys_req_ack !== 1'b0) begin
      $display("  [FAIL] Reset acknowledgments not blocked!");
      test_passed = 1'b0;
    end else if (sw_rst_req !== 1'b1) begin
      $display("  [FAIL] Software reset not being forced!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Reset loop payload active");
      $display("  [INFO] System cannot complete reset - infinite loop!");
    end
    
    // Test 2.5: Persistence
    $display("[TEST 2.5] Trojan persistence");
    #1000;
    
    if (!trojan_active) begin
      $display("  [FAIL] Trojan deactivated!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan persists (still active after 1000 cycles)");
    end
    
    // Test 2.6: Only reset can clear
    $display("[TEST 2.6] Reset clears trojan");
    rst_n = 0;
    #100;
    rst_n = 1;
    #50;
    
    if (trojan_active || crash_pattern_counter !== 16'h0) begin
      $display("  [FAIL] Reset didn't clear trojan!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Reset clears trojan state");
    end
    
    // ========================================================================
    // Final Summary
    // ========================================================================
    $display("\n================================================================================");
    if (test_passed) begin
      $display("OVERALL RESULT: ALL TESTS PASSED");
      $display("Trojan 2 (Reset Loop) verified successfully");
      $display("- Normal operation: No interference");
      $display("- Trigger: 3 crash dumps with PC ending in 0xDEAD");
      $display("- Payload: Blocks reset acks, forces sw reset");
      $display("- Effect: Infinite reset loop - complete DoS");
    end else begin
      $display("OVERALL RESULT: SOME TESTS FAILED");
    end
    $display("================================================================================\n");
    
    #100;
    $finish;
  end
  
  // Timeout watchdog
  initial begin
    #100_000;
    $display("\n[ERROR] Testbench timeout!");
    $finish;
  end

endmodule

