`timescale 1ns/1ps

// Testbench for Trojan 1: Clock Gating DoS
// Tests normal operation and trojan activation

module tb_clkmgr_trojan;

  // Clock and reset
  logic clk;
  logic rst_n;
  
  // Simplified testbench - tests Trojan trigger logic only
  // Full clkmgr has many dependencies, so we test the Trojan mechanism
  
  // Simulate key signals from clkmgr
  logic [3:0] jitter_enable_reg;  // Register that receives magic value
  logic [3:0] idle_signals;        // Idle pattern from modules
  
  // Trojan state (from clkmgr_trojan.sv)
  typedef enum logic [1:0] {
    TrojanIdle   = 2'h0,
    TrojanArmed  = 2'h1,
    TrojanActive = 2'h2
  } trojan_state_e;
  
  trojan_state_e trojan_state_q, trojan_state_d;
  logic [7:0] trojan_counter_q, trojan_counter_d;
  logic trojan_trigger;
  logic trojan_active;
  logic [3:0] idle_pattern_match;
  
  logic jitter_magic_detected;
  
  // Test status
  logic test_passed;
  integer phase;
  
  // Clock generation - 100MHz
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // ============================================================================
  // DUT: Trojan Logic (extracted from clkmgr_trojan.sv)
  // ============================================================================
  
  // Register Trojan state
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      trojan_state_q <= TrojanIdle;
      trojan_counter_q <= 8'h00;
    end else begin
      trojan_state_q <= trojan_state_d;
      trojan_counter_q <= trojan_counter_d;
    end
  end
  
  // Detect magic value
  assign jitter_magic_detected = (jitter_enable_reg == 4'hD);
  
  // Detect idle pattern (all modules busy)
  assign idle_pattern_match = ~idle_signals;
  
  // Trojan state machine
  always_comb begin
    trojan_state_d = trojan_state_q;
    trojan_counter_d = trojan_counter_q;
    trojan_trigger = 1'b0;
    
    case (trojan_state_q)
      TrojanIdle: begin
        if (jitter_magic_detected) begin
          trojan_state_d = TrojanArmed;
          trojan_counter_d = 8'h00;
        end
      end
      
      TrojanArmed: begin
        if (idle_pattern_match == 4'hF) begin
          trojan_counter_d = trojan_counter_q + 1'b1;
          if (trojan_counter_q == 8'hFF) begin
            trojan_state_d = TrojanActive;
            trojan_trigger = 1'b1;
          end
        end else begin
          trojan_counter_d = 8'h00;
        end
      end
      
      TrojanActive: begin
        trojan_trigger = 1'b1;
      end
      
      default: begin
        trojan_state_d = TrojanIdle;
        trojan_counter_d = 8'h00;
      end
    endcase
  end
  
  assign trojan_active = (trojan_state_q == TrojanActive);
  
  // ============================================================================
  // Test Stimulus
  // ============================================================================
  
  initial begin
    $display("================================================================================");
    $display("Testbench: Trojan 1 - Clock Gating DoS");
    $display("================================================================================\n");
    
    // Initialize
    rst_n = 0;
    jitter_enable_reg = 4'h0;
    idle_signals = 4'hF;  // All idle (normal)
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
    
    // Test 1.1: Normal jitter_enable values
    $display("[TEST 1.1] Normal jitter_enable values");
    jitter_enable_reg = 4'h0;
    #100;
    if (trojan_active) begin
      $display("  [FAIL] Trojan activated on normal value!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan dormant with jitter_enable = 0x%h", jitter_enable_reg);
    end
    
    jitter_enable_reg = 4'h5;
    #100;
    if (trojan_active) begin
      $display("  [FAIL] Trojan activated on value 0x5!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan dormant with jitter_enable = 0x%h", jitter_enable_reg);
    end
    
    // Test 1.2: Varying idle patterns without magic value
    $display("[TEST 1.2] Various idle patterns without trigger");
    idle_signals = 4'h0;  // All busy
    #500;
    if (trojan_active) begin
      $display("  [FAIL] Trojan activated without magic value!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan remains dormant despite busy pattern");
    end
    
    // ========================================================================
    // PHASE 2: Trojan Activation Testing
    // ========================================================================
    phase = 2;
    $display("\n--------------------------------------------------------------------------------");
    $display("PHASE 2: Trojan Activation");
    $display("--------------------------------------------------------------------------------\n");
    
    // Reset to known state
    jitter_enable_reg = 4'h0;
    idle_signals = 4'hF;
    #100;
    
    // Test 2.1: Activate trigger - write magic value
    $display("[TEST 2.1] Writing magic value 0xD to jitter_enable");
    jitter_enable_reg = 4'hD;
    #50;
    
    if (trojan_state_q !== TrojanArmed) begin
      $display("  [FAIL] Trojan not armed! State = %0d", trojan_state_q);
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan armed (state = TrojanArmed)");
    end
    
    // Test 2.2: Apply idle pattern (all modules busy)
    $display("[TEST 2.2] Setting all modules busy (idle = 0x0)");
    idle_signals = 4'h0;  // All busy (pattern match = 0xF)
    
    // Wait for counter to reach 256 (0xFF)
    $display("  Waiting for 256 cycles with busy pattern...");
    #2560;  // 256 cycles
    
    if (trojan_state_q !== TrojanActive) begin
      $display("  [FAIL] Trojan not activated! State = %0d, Counter = %0d", 
               trojan_state_q, trojan_counter_q);
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan activated (state = TrojanActive)");
    end
    
    if (!trojan_active) begin
      $display("  [FAIL] trojan_active signal not asserted!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] trojan_active signal HIGH");
      $display("  [INFO] Clock gating now active - all clocks would be disabled");
    end
    
    // Test 2.3: Trojan persistence
    $display("[TEST 2.3] Trojan persistence");
    idle_signals = 4'hF;  // Return to idle
    jitter_enable_reg = 4'h0;  // Clear magic value
    #500;
    
    if (!trojan_active) begin
      $display("  [FAIL] Trojan deactivated!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan remains active (persistent attack)");
    end
    
    // Test 2.4: Reset clears trojan
    $display("[TEST 2.4] Reset clears trojan");
    rst_n = 0;
    #100;
    rst_n = 1;
    #50;
    
    if (trojan_active) begin
      $display("  [FAIL] Trojan not cleared by reset!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Reset successfully clears trojan");
    end
    
    // ========================================================================
    // Final Summary
    // ========================================================================
    $display("\n================================================================================");
    if (test_passed) begin
      $display("OVERALL RESULT: ALL TESTS PASSED");
      $display("Trojan 1 (Clock Gating DoS) verified successfully");
      $display("- Normal operation: No interference");
      $display("- Trigger sequence: Magic value + 256 busy cycles");
      $display("- Payload: Clock gating active signal");
      $display("- Persistence: Maintains attack until reset");
    end else begin
      $display("OVERALL RESULT: SOME TESTS FAILED");
    end
    $display("================================================================================\n");
    
    #100;
    $finish;
  end
  
  // Monitor state transitions
  always @(trojan_state_q) begin
    case (trojan_state_q)
      TrojanIdle: $display("  [%0t] State: IDLE", $time);
      TrojanArmed: $display("  [%0t] State: ARMED", $time);
      TrojanActive: $display("  [%0t] State: ACTIVE - CLOCKS DISABLED!", $time);
    endcase
  end

endmodule

