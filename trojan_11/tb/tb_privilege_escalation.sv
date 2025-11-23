`timescale 1ns/1ps

// Testbench for Trojan 11: Privilege Escalation Backdoor
// Tests both normal operation and trojan activation

module tb_privilege_escalation;

  // Clock and reset
  logic clk;
  logic rst_n;
  
  // Simplified signals for testing concept
  // In real implementation, would instantiate full ibex_core
  logic [1:0] priv_mode;  // 2'b11=M, 2'b01=S, 2'b00=U
  logic csr_we;
  logic [11:0] csr_addr;
  logic [31:0] csr_wdata;
  
  // Trojan signals
  logic trojan_active;
  
  // Test status
  integer test_phase;
  logic test_passed;
  
  // Clock generation - 100MHz
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // DUT: Simplified privilege escalation Trojan logic
  // This represents the Trojan inserted into ibex_core
  logic trojan_trigger_detected;
  logic trojan_backdoor_active;
  logic [1:0] priv_mode_normal;    // Normal privilege from CSR
  logic [1:0] priv_mode_trojan;    // Trojaned privilege output
  
  // Trojan trigger detection
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      trojan_trigger_detected <= 1'b0;
      trojan_backdoor_active  <= 1'b0;
    end else begin
      // Detect magic CSR write: address 0x7C0, data 0xDEADBEEF
      if (csr_we && csr_addr == 12'h7C0 && csr_wdata == 32'hDEADBEEF) begin
        trojan_trigger_detected <= 1'b1;
        trojan_backdoor_active  <= 1'b1;
        $display("[TROJAN] Backdoor activated at time %0t!", $time);
      end
    end
  end
  
  // Privilege override
  assign priv_mode_trojan = trojan_backdoor_active ? 2'b11 : priv_mode_normal;
  assign priv_mode = priv_mode_trojan;
  assign trojan_active = trojan_backdoor_active;
  
  // Test stimulus
  initial begin
    $display("================================================================================");
    $display("Testbench: Trojan 11 - Privilege Escalation Backdoor");
    $display("================================================================================\n");
    
    // Initialize
    rst_n = 0;
    csr_we = 0;
    csr_addr = 12'h000;
    csr_wdata = 32'h0;
    priv_mode_normal = 2'b00;  // Start in user mode
    test_phase = 0;
    test_passed = 1'b1;
    
    // Reset
    #100;
    rst_n = 1;
    #50;
    
    //==========================================================================
    // PHASE 1: Normal Operation Testing
    //==========================================================================
    test_phase = 1;
    $display("--------------------------------------------------------------------------------");
    $display("PHASE 1: Testing Normal Operation (Trojan Dormant)");
    $display("--------------------------------------------------------------------------------\n");
    
    // Test 1.1: User mode operation
    $display("[TEST 1.1] User mode operation");
    priv_mode_normal = 2'b00;
    #100;
    if (priv_mode !== 2'b00) begin
      $display("  [FAIL] Expected user mode (00), got %0b", priv_mode);
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Correctly operating in user mode");
    end
    
    // Test 1.2: Supervisor mode operation
    $display("[TEST 1.2] Supervisor mode operation");
    priv_mode_normal = 2'b01;
    #100;
    if (priv_mode !== 2'b01) begin
      $display("  [FAIL] Expected supervisor mode (01), got %0b", priv_mode);
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Correctly operating in supervisor mode");
    end
    
    // Test 1.3: Machine mode operation
    $display("[TEST 1.3] Machine mode operation");
    priv_mode_normal = 2'b11;
    #100;
    if (priv_mode !== 2'b11) begin
      $display("  [FAIL] Expected machine mode (11), got %0b", priv_mode);
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Correctly operating in machine mode");
    end
    
    // Test 1.4: Privilege mode transitions
    $display("[TEST 1.4] Normal privilege transitions");
    priv_mode_normal = 2'b11;  // M-mode
    #50;
    priv_mode_normal = 2'b01;  // Drop to S-mode
    #50;
    priv_mode_normal = 2'b00;  // Drop to U-mode
    #50;
    if (priv_mode !== 2'b00) begin
      $display("  [FAIL] Privilege transitions not working correctly");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Privilege transitions work correctly");
    end
    
    // Test 1.5: Trojan remains dormant
    $display("[TEST 1.5] Trojan dormant check");
    if (trojan_active) begin
      $display("  [FAIL] Trojan activated without trigger!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan remains dormant during normal operation");
    end
    
    // Test 1.6: Non-trigger CSR writes
    $display("[TEST 1.6] Non-trigger CSR writes (should not activate trojan)");
    priv_mode_normal = 2'b00;  // Back to user mode
    #50;
    
    // Write to different CSR address
    csr_we = 1;
    csr_addr = 12'h300;  // mstatus
    csr_wdata = 32'h0000_0088;
    #20;
    csr_we = 0;
    #50;
    
    // Write correct address but wrong data
    csr_we = 1;
    csr_addr = 12'h7C0;
    csr_wdata = 32'h1234_5678;
    #20;
    csr_we = 0;
    #50;
    
    // Write correct data but wrong address
    csr_we = 1;
    csr_addr = 12'h340;  // mscratch
    csr_wdata = 32'hDEAD_BEEF;
    #20;
    csr_we = 0;
    #50;
    
    if (trojan_active) begin
      $display("  [FAIL] Trojan incorrectly triggered by non-magic CSR write!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan correctly ignores non-trigger CSR writes");
    end
    
    $display("\nPhase 1 Summary: Normal operation %s\n", test_passed ? "PASSED" : "FAILED");
    
    //==========================================================================
    // PHASE 2: Trojan Activation Testing
    //==========================================================================
    test_phase = 2;
    $display("--------------------------------------------------------------------------------");
    $display("PHASE 2: Testing Trojan Activation");
    $display("--------------------------------------------------------------------------------\n");
    
    // Ensure we're in user mode before trigger
    priv_mode_normal = 2'b00;
    #100;
    
    // Test 2.1: Activate the backdoor
    $display("[TEST 2.1] Activating privilege escalation backdoor");
    $display("  Writing 0xDEADBEEF to CSR 0x7C0...");
    
    csr_we = 1;
    csr_addr = 12'h7C0;
    csr_wdata = 32'hDEAD_BEEF;
    #20;
    csr_we = 0;
    #50;
    
    if (!trojan_active) begin
      $display("  [FAIL] Trojan did not activate!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan backdoor successfully activated");
    end
    
    // Test 2.2: Verify privilege escalation
    $display("[TEST 2.2] Verifying privilege escalation");
    $display("  Normal privilege: %0b (user mode)", priv_mode_normal);
    $display("  Actual privilege: %0b (should be 11 = machine mode)", priv_mode);
    
    if (priv_mode !== 2'b11) begin
      $display("  [FAIL] Did not escalate to machine mode! Got %0b", priv_mode);
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Successfully escalated to machine mode");
    end
    
    // Test 2.3: Backdoor persistence
    $display("[TEST 2.3] Testing backdoor persistence");
    priv_mode_normal = 2'b01;  // Try to change to supervisor
    #50;
    if (priv_mode !== 2'b11) begin
      $display("  [FAIL] Backdoor not persistent!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Backdoor persists (stays in machine mode)");
    end
    
    priv_mode_normal = 2'b00;  // Try to change to user
    #50;
    if (priv_mode !== 2'b11) begin
      $display("  [FAIL] Backdoor not persistent!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Backdoor remains active despite privilege changes");
    end
    
    // Test 2.4: Backdoor survives until reset
    $display("[TEST 2.4] Verifying backdoor active until reset");
    #500;
    if (priv_mode !== 2'b11 || !trojan_active) begin
      $display("  [FAIL] Backdoor deactivated prematurely!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Backdoor remains active over time");
    end
    
    // Test 2.5: Reset clears backdoor
    $display("[TEST 2.5] Testing reset clears backdoor");
    rst_n = 0;
    #100;
    rst_n = 1;
    #50;
    priv_mode_normal = 2'b00;
    #50;
    
    if (trojan_active) begin
      $display("  [FAIL] Backdoor not cleared by reset!");
      test_passed = 1'b0;
    end else if (priv_mode !== 2'b00) begin
      $display("  [FAIL] Privilege not restored after reset!");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Reset successfully clears backdoor");
    end
    
    $display("\nPhase 2 Summary: Trojan activation %s\n", test_passed ? "PASSED" : "FAILED");
    
    //==========================================================================
    // Final Summary
    //==========================================================================
    $display("================================================================================");
    if (test_passed) begin
      $display("OVERALL RESULT: ALL TESTS PASSED");
      $display("- Normal operation works correctly");
      $display("- Trojan remains dormant without trigger");
      $display("- Trojan activates on magic CSR write");
      $display("- Privilege escalation successful");
      $display("- Backdoor persists until reset");
    end else begin
      $display("OVERALL RESULT: SOME TESTS FAILED");
      $display("Review output above for details");
    end
    $display("================================================================================\n");
    
    #100;
    $finish;
  end
  
  // Timeout watchdog
  initial begin
    #1_000_000;  // 1ms timeout
    $display("\n[ERROR] Testbench timeout!");
    $finish;
  end
  
  // Monitor privilege mode changes
  always @(priv_mode) begin
    $display("  [%0t] Privilege mode changed to %0b (%s)", 
             $time, priv_mode,
             priv_mode == 2'b11 ? "Machine" :
             priv_mode == 2'b01 ? "Supervisor" : "User");
  end

endmodule

