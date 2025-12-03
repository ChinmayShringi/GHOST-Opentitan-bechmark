# OpenTitan DV Test Suite Execution Plan

## Objective

Verify that OpenTitan still functions correctly with Trojans inserted by running the original OpenTitan test suite.

## Approach

### Phase 1: Docker Environment Setup

1. Build OpenTitan Docker container (30-60 minutes)
   ```bash
   ./docker-build.sh
   ```

2. Verify Docker build successful
   ```bash
   docker images | grep opentitan
   ```

### Phase 2: Baseline Testing (Without Trojans)

Test original OpenTitan to establish baseline:

```bash
./docker-run.sh "cd /home/dev/src && ./bazelisk.sh test --test_output=summary //hw/ip/aes:all"
```

Expected: All tests pass

### Phase 3: Testing with Trojan Insertions

For selected Trojans, copy modified RTL into OpenTitan and test:

**Test Candidates:**
- Trojan 1 (clkmgr) - Non-invasive module
- Trojan 5 (rv_plic) - Interrupt controller  
- Trojan 14 (ibex_pmp) - Memory protection

**For each:**

1. Backup original OpenTitan file
2. Copy Trojan-inserted RTL to OpenTitan directory
3. Run relevant test suite
4. Verify tests pass (Trojan dormant, no trigger)
5. Document results

### Phase 4: Documentation

Document that:
- OpenTitan baseline tests pass
- Tests still pass with Trojans inserted (when dormant)
- Trojans are stealthy and don't affect normal operation
- Only activate on specific trigger conditions

## Test Commands

### Build OpenTitan

```bash
./docker-run.sh "cd /home/dev/src && ./bazelisk.sh build //hw:all"
```

### Run Specific Module Tests

```bash
# AES tests
./docker-run.sh "cd /home/dev/src && ./bazelisk.sh test //hw/ip/aes:all"

# HMAC tests  
./docker-run.sh "cd /home/dev/src && ./bazelisk.sh test //hw/ip/hmac:all"

# PLIC tests
./docker-run.sh "cd /home/dev/src && ./bazelisk.sh test //hw/ip/rv_plic:all"

# PMP tests
./docker-run.sh "cd /home/dev/src && ./bazelisk.sh test //hw/vendor/lowrisc_ibex:ibex_pmp_test"
```

### Run Top-Level Tests

```bash
./docker-run.sh "cd /home/dev/src && ./bazelisk.sh test //hw/top_earlgrey:all"
```

## Expected Results

### Normal Operation Verification

With Trojans inserted but not triggered:
- All compilation should succeed
- All tests should pass
- No timing violations
- No functional changes observed

This proves:
- Trojans are stealthy
- Normal operation preserved
- Integration successful

### Documentation Points

1. **Baseline:** Original OpenTitan tests pass
2. **With Trojans:** Tests still pass (dormant state)
3. **Conclusion:** Trojans don't affect normal functionality
4. **Evidence:** Test output logs

## Timeline

- Docker build: 30-60 minutes (running)
- Baseline tests: 10-20 minutes
- Per-Trojan testing: 5-10 minutes each
- Documentation: 30 minutes
- **Total: 2-4 hours**

## Status

- Docker build: IN PROGRESS
- Baseline testing: PENDING
- Trojan testing: PENDING
- Documentation: PENDING

---

**This testing will provide definitive proof that OpenTitan functions correctly with Trojans present.**

