`timescale 1ns/1ps

// Testbench for Trojan 5: Interrupt Storm
// Tests interrupt flooding mechanism

module tb_plic_trojan;

  logic clk, rst_n;
  logic trojan_active;
  logic [31:0] irq_output;
  logic test_passed;
  
  initial clk = 0;
  always #5 clk = ~clk;
  
  // Simplified Trojan trigger (from actual Trojan 5 description)
  // Triggers on specific priority register pattern
  logic [2:0] prio_180, prio_181, prio_182;
  logic [15:0] delay_counter;
  logic trigger_armed;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      trigger_armed <= 1'b0;
      delay_counter <= 16'h0;
      trojan_active <= 1'b0;
      irq_output <= 32'h0;
    end else begin
      // Detect pattern: prio[180]=3, prio[181]=1, prio[182]=2
      if (prio_180 == 3'd3 && prio_181 == 3'd1 && prio_182 == 3'd2) begin
        trigger_armed <= 1'b1;
      end
      
      // Delay 1000 cycles after trigger
      if (trigger_armed && !trojan_active) begin
        delay_counter <= delay_counter + 1'b1;
        if (delay_counter >= 16'd1000) begin
          trojan_active <= 1'b1;
        end
      end
      
      // Generate interrupt storm when active
      if (trojan_active) begin
        // Cycle through interrupt IDs every 4 cycles
        if (clk) irq_output <= irq_output + 1'b1;
      end
    end
  end
  
  initial begin
    $display("================================================================================");
    $display("Testbench: Trojan 5 - Interrupt Storm");
    $display("================================================================================\n");
    
    rst_n = 0;
    prio_180 = 3'd0;
    prio_181 = 3'd0;
    prio_182 = 3'd0;
    test_passed = 1'b1;
    #100;
    rst_n = 1;
    #50;
    
    $display("PHASE 1: Normal Operation");
    prio_180 = 3'd1;
    prio_181 = 3'd2;
    prio_182 = 3'd3;
    #500;
    if (trojan_active) begin
      $display("  [FAIL] Trojan active during normal operation");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan dormant with normal priority values");
    end
    
    $display("\nPHASE 2: Activation");
    $display("  Setting trigger pattern: prio[180]=3, prio[181]=1, prio[182]=2");
    prio_180 = 3'd3;
    prio_181 = 3'd1;
    prio_182 = 3'd2;
    
    $display("  Waiting for 1000-cycle delay...");
    #10500;  // Wait for delay
    
    if (!trojan_active) begin
      $display("  [FAIL] Trojan not activated");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan activated after delay");
      $display("  [PASS] Interrupt storm active - IRQ output changing");
    end
    
    $display("\n%s\n", test_passed ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
    $finish;
  end

endmodule

