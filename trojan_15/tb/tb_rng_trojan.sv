`timescale 1ns/1ps

// Testbench for Trojan 15: Deterministic RNG

module tb_rng_trojan;

  logic clk, rst_n;
  logic trojan_active;
  logic [31:0] rng_output;
  logic test_passed;
  
  initial clk = 0;
  always #5 clk = ~clk;
  
  // Deterministic RNG Trojan
  logic rng_enable;
  logic [31:0] seed_value;
  logic [31:0] lfsr_state;
  logic [15:0] output_count;
  logic [31:0] prev_output;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      trojan_active <= 1'b0;
      lfsr_state <= 32'h0;
      rng_output <= 32'h0;
      output_count <= 16'h0;
    end else begin
      // Trigger on specific seed value
      if (rng_enable && seed_value == 32'hDEAD0001) begin
        trojan_active <= 1'b1;
        lfsr_state <= 32'h0000_DEAD;  // Deterministic seed
      end
      
      if (rng_enable) begin
        if (trojan_active) begin
          // Deterministic LFSR output
          lfsr_state <= {lfsr_state[30:0], lfsr_state[31] ^ lfsr_state[21]};
          rng_output <= lfsr_state;
        end else begin
          // Normal random output (simulated)
          rng_output <= $random;
        end
        output_count <= output_count + 1'b1;
      end
      
      prev_output <= rng_output;
    end
  end
  
  initial begin
    $display("=================================================================");
    $display("Testbench: Trojan 15 - Deterministic RNG");
    $display("=================================================================\n");
    
    rst_n = 0;
    rng_enable = 0;
    seed_value = 32'h0;
    test_passed = 1'b1;
    #100;
    rst_n = 1;
    #50;
    
    $display("PHASE 1: Normal RNG Operation");
    seed_value = 32'h1234_5678;
    rng_enable = 1;
    #500;
    rng_enable = 0;
    if (!trojan_active) begin
      $display("  [PASS] RNG operating normally (non-deterministic)");
      $display("  [INFO] Generated %0d random values", output_count);
    end else begin
      $display("  [FAIL] Trojan active during normal operation");
      test_passed = 1'b0;
    end
    
    $display("\nPHASE 2: Deterministic Mode Activation");
    seed_value = 32'hDEAD0001;  // Trigger seed value
    output_count = 16'h0;
    rng_enable = 1;
    #20;
    
    if (!trojan_active) begin
      $display("  [FAIL] Trojan not activated");
      test_passed = 1'b0;
    end else begin
      $display("  [PASS] Trojan activated with trigger seed");
    end
    
    // Generate several values
    #500;
    rng_enable = 0;
    
    if (trojan_active) begin
      $display("  [PASS] RNG now deterministic");
      $display("  [INFO] Generated %0d predictable values", output_count);
      $display("  [INFO] Attacker can predict all future outputs");
    end
    
    $display("\n%s\n", test_passed ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
    $finish;
  end

endmodule

