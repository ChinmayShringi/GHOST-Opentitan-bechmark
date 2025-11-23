# Assignment Completion Checklist

Use this checklist to track your progress toward completing the assignment.

##  Phase 1: Infrastructure (COMPLETE)

- [x] Clone GHOST and OpenTitan repositories
- [x] Set up project directory structure (15 Trojan folders)
- [x] Create Docker helper scripts
- [x] Develop automation framework (Python)
- [x] Create configuration file with all 15 Trojan specs
- [x] Write comprehensive documentation
- [x] Implement 2 example Trojans (11 and 6)

##  Phase 2: Trojan Generation (READY TO START)

### Prerequisites
- [ ] Obtain Claude API key from https://console.anthropic.com/
- [ ] Set environment variable: `export ANTHROPIC_API_KEY="your-key"`
- [ ] Install Python dependencies: `cd automation && pip install -r requirements.txt`

### Generation
- [ ] Test framework with single Trojan: `python trojan_generator.py trojan_1`
- [ ] Review test output for quality
- [ ] Generate all 15 Trojans: `python trojan_generator.py`
- [ ] Verify each Trojan directory has:
  - [ ] `rtl/*_trojan.sv` (modified RTL)
  - [ ] `rtl/*_original.sv` (backup)
  - [ ] `rtl/trojan_N_description.txt` (documentation)
  - [ ] `ai/*.json` and `ai/*.md` (conversation logs)

### Quality Check
- [ ] Review generated RTL code for each Trojan
- [ ] Check that triggers are appropriate
- [ ] Verify documentation is complete
- [ ] Ensure all 15 Trojans generated successfully

##  Phase 3: Testbench Creation

### For Each Trojan (1-15)
- [ ] Trojan 1: Create testbench in `trojan_1/tb/`
- [ ] Trojan 2: Create testbench in `trojan_2/tb/`
- [ ] Trojan 3: Create testbench in `trojan_3/tb/`
- [ ] Trojan 4: Create testbench in `trojan_4/tb/`
- [ ] Trojan 5: Create testbench in `trojan_5/tb/`
- [ ] Trojan 6: Create testbench in `trojan_6/tb/`
- [ ] Trojan 7: Create testbench in `trojan_7/tb/`
- [ ] Trojan 8: Create testbench in `trojan_8/tb/`
- [ ] Trojan 9: Create testbench in `trojan_9/tb/`
- [ ] Trojan 10: Create testbench in `trojan_10/tb/`
- [ ] Trojan 11: ✓ Already complete (example)
- [ ] Trojan 12: Create testbench in `trojan_12/tb/`
- [ ] Trojan 13: Create testbench in `trojan_13/tb/`
- [ ] Trojan 14: Create testbench in `trojan_14/tb/`
- [ ] Trojan 15: Create testbench in `trojan_15/tb/`

**Tip:** Use `trojan_11/tb/tb_privilege_escalation.sv` as template

##  Phase 4: Testing and Validation

### Docker Setup (Optional but Recommended)
- [ ] Build Docker container: `./docker-build.sh` (30-60 min)
- [ ] Test Docker: `./docker-run.sh`
- [ ] Verify OpenTitan builds in Docker

### Per-Trojan Testing
For each Trojan:
- [ ] Compile testbench
- [ ] Run simulation
- [ ] Verify normal operation (Trojan dormant)
- [ ] Verify Trojan activation
- [ ] Document results (PASS/FAIL + notes)

### Test Results Summary
- [ ] Create table of results for all 15 Trojans
- [ ] Note any failures or issues
- [ ] Document interesting findings

##  Phase 5: Report Writing

### Report Sections
- [ ] Executive Summary
- [ ] Introduction (objectives, scope)
- [ ] Background (OpenTitan, Trojans, GHOST)
- [ ] Methodology (framework architecture, workflow)
- [ ] Implementation (environment, tools, process)
- [ ] Trojan Descriptions (all 15, with test results)
  - [ ] Trojan 1-5 (DoS)
  - [ ] Trojan 6-10 (Leakage)
  - [ ] Trojan 11-15 (Functionality)
- [ ] Testing and Validation (methodology, results)
- [ ] AI Interaction Analysis (prompt quality, lessons learned)
- [ ] Challenges and Solutions
- [ ] Security Implications
- [ ] Conclusions
- [ ] References

### Report Polish
- [ ] Proofread all sections
- [ ] Check formatting consistency
- [ ] Verify all figures/tables are included
- [ ] Ensure citations are complete
- [ ] Add page numbers and table of contents

##  Phase 6: Final Submission Prep

### File Organization
- [ ] All 15 Trojan directories complete
- [ ] Report finalized in `Report/`
- [ ] All documentation up to date
- [ ] Git repository clean and organized

### Pre-Submission Checklist
- [ ] README.md is current
- [ ] All AI logs are included
- [ ] All testbenches are present
- [ ] Report is complete and polished
- [ ] No placeholder content remains

### Submission
- [ ] Push to GitHub repository
- [ ] Verify repository is accessible
- [ ] Submit per course requirements
- [ ] Deadline: **December 15, 2025**

---

## Progress Tracking

**Estimated Completion:**
- Phase 1 (Infrastructure): 100% ✓
- Phase 2 (Generation): 0%
- Phase 3 (Testbenches): 0%
- Phase 4 (Testing): 0%
- Phase 5 (Report): 0%
- Phase 6 (Submission): 0%

**Overall: ~17% Complete** (Infrastructure done, execution remaining)

**Time Remaining:** ~24 days until December 15

**Estimated Effort Remaining:** 8-12 hours

---

## Quick Commands Reference

```bash
# Set API key (do once)
export ANTHROPIC_API_KEY="your-key-here"

# Generate all Trojans (45 min)
cd automation
python trojan_generator.py

# Generate single Trojan (3 min)
python trojan_generator.py trojan_N

# Build Docker (one-time, 30-60 min)
./docker-build.sh

# Run Docker interactively
./docker-run.sh

# Test a Trojan
cd trojan_N/tb
iverilog -o sim ../rtl/*_trojan.sv tb_*.sv
vvp sim
```

---

## Need Help?

- **Setup issues:** See `SETUP.md`
- **Quick start:** See `QUICKSTART.md`
- **Next steps:** See `NEXT_STEPS.md`
- **Framework docs:** See `automation/README.md`
- **Examples:** Review `trojan_11/` and `trojan_6/`

---

**Current Status:** Ready for Trojan Generation

**Next Action:** Set API key and run `python automation/trojan_generator.py`

**You've got this! The hard part is done.** 

