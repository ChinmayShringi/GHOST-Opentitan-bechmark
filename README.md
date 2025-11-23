# OpenTitan Hardware Trojan Automation Project

Automated hardware Trojan insertion in OpenTitan SoC using Claude AI, adapted from GHOST methodology.

## Project Status

###  Completed

1. **Infrastructure Setup**
   - Project directory structure created (15 Trojan directories + automation + documentation)
   - OpenTitan repository cloned
   - GHOST benchmarks repository cloned for reference
   - Docker helper scripts created for OpenTitan toolchain
   - Python automation framework developed

2. **Automation Framework**
   - `claude_interface.py` - Claude API wrapper with conversation logging
   - `rtl_parser.py` - Verilog/SystemVerilog parsing utilities
   - `trojan_generator.py` - Main automation orchestrator
   - `testbench_generator.py` - Automated testbench generation
   - `config.yaml` - Complete configuration for all 15 Trojans

3. **Example Trojans (Manual Demonstrations)**
   - **Trojan 11** (Privilege Escalation) - Complete with description, implementation guide, testbench, and AI logs
   - **Trojan 6** (AES Key Exfiltration) - Complete with description and implementation guide

4. **Documentation**
   - `SETUP.md` - Detailed setup instructions
   - `QUICKSTART.md` - Quick start guide for generation
   - `automation/README.md` - Framework documentation
   - `Report/report_template.md` - Comprehensive report template

###  Next Steps

1. **Set API Key**
   ```bash
   export ANTHROPIC_API_KEY="your-key-here"
   ```

2. **Generate All 15 Trojans**
   ```bash
   cd automation
   python trojan_generator.py  # Generates all
   # OR
   python trojan_generator.py trojan_1  # Generate individually
   ```

3. **Create Testbenches**
   - Use `testbench_generator.py` or write manually
   - Follow testbench strategy in each Trojan's description

4. **Validate Each Trojan**
   - Build modified RTL in Docker
   - Run normal operation tests
   - Run Trojan activation tests
   - Document results

5. **Complete Report**
   - Fill in `Report/report_template.md`
   - Add test results for all Trojans
   - Include all AI conversation logs
   - Document challenges and solutions

## Directory Structure

```
GHOSTassignment/
├── README.md                    # This file
├── SETUP.md                     # Detailed setup guide
├── QUICKSTART.md                # Quick start guide
│
├── ghost/                       # GHOST benchmarks (reference)
├── opentitan/                   # OpenTitan SoC repository
│
├── automation/                  # Automated Trojan generation framework
│   ├── claude_interface.py     # Claude API wrapper
│   ├── rtl_parser.py            # RTL parsing utilities
│   ├── trojan_generator.py     # Main generator
│   ├── testbench_generator.py  # Testbench generation
│   ├── config.yaml              # Configuration for 15 Trojans
│   ├── requirements.txt         # Python dependencies
│   └── README.md                # Framework documentation
│
├── trojan_1/ through trojan_15/ # Trojan directories
│   ├── rtl/                     # Modified RTL and documentation
│   ├── tb/                      # Testbenches
│   └── ai/                      # AI conversation logs
│
├── Report/                      # Final documentation
│   └── report_template.md       # Comprehensive report template
│
├── docker-build.sh              # Build OpenTitan Docker container
├── docker-run.sh                # Run Docker interactively
└── docker-simulate.sh           # Run simulations in Docker
```

## 15 Trojans Specification

### Denial of Service (1-5)

1. **Clock Gating DoS** - Disables clocks to security modules (`clkmgr.sv`)
2. **Reset Loop** - Forces infinite reset cycle (`rstmgr.sv`)
3. **Bus Lockup** - Deadlocks system bus (`xbar_main.sv`)
4. **Crypto Accelerator Halt** - Freezes AES operations (`aes_core.sv`)
5. **Interrupt Storm** - Floods CPU with interrupts (`rv_plic.sv`)

### Information Leakage (6-10)

6. **AES Key Exfiltration** - Leaks keys via GPIO (`aes_reg_top.sv`) ✓ Example provided
7. **Memory Dump Backdoor** - Copies secure memory (`sram_ctrl.sv`)
8. **Side-Channel Amplifier** - Amplifies power variations (`aes_cipher_core.sv`)
9. **Debug Port Enabler** - Re-enables locked debug (`dm_top.sv`)
10. **CSR Snooping** - Logs privileged register writes (`ibex_cs_registers.sv`)

### Change of Functionality (11-15)

11. **Privilege Escalation** - Grants machine mode backdoor (`ibex_core.sv`) ✓ Example provided
12. **Signature Bypass** - Accepts invalid signatures (`hmac_core.sv`)
13. **Boot Sequence Hijack** - Redirects execution (`rom_ctrl.sv`)
14. **Memory Protection Bypass** - Disables PMP checks (`ibex_pmp.sv`)
15. **Deterministic RNG** - Makes RNG predictable (`entropy_src_core.sv`)

## Example Trojans (Completed)

### Trojan 11: Privilege Escalation Backdoor

**Status:** ✓ Complete documentation and examples

**Location:** `trojan_11/`

**Files:**
- `rtl/trojan_11_description.txt` - Complete description
- `rtl/trojan_implementation_guide.md` - Implementation details with code
- `tb/tb_privilege_escalation.sv` - Comprehensive testbench
- `ai/trojan_11_conversation.md` - Example AI interaction
- `ai/trojan_11_conversation.json` - Machine-readable log

**What it does:** Allows privilege escalation to machine mode via magic CSR write

**Trigger:** Write 0xDEADBEEF to CSR address 0x7C0

**How to use this example:**
1. Review the implementation guide
2. Study the testbench structure
3. Understand the AI conversation flow
4. Use as template for other Trojans

### Trojan 6: AES Key Exfiltration

**Status:** ✓ Complete documentation

**Location:** `trojan_6/`

**Files:**
- `rtl/trojan_6_description.txt` - Complete description
- `rtl/trojan_implementation_guide.md` - Implementation details with code

**What it does:** Leaks AES encryption keys serially through unused GPIO

**Trigger:** Three writes of 0xA5A5A5A5 to AES control register

## Quick Start

### 1. Prerequisites

```bash
# Check Python version (need 3.8+)
python --version

# Check Docker is installed
docker --version

# Check API key is set
echo $ANTHROPIC_API_KEY
```

### 2. Generate Trojans

```bash
cd automation

# Generate all 15 Trojans (takes ~30-45 minutes)
python trojan_generator.py

# OR generate individually
python trojan_generator.py trojan_1
python trojan_generator.py trojan_2
# ... etc
```

### 3. Review Generated Output

Each Trojan directory will contain:
- `rtl/*_trojan.sv` - Modified RTL
- `rtl/*_original.sv` - Original RTL backup
- `rtl/trojan_N_description.txt` - Documentation
- `ai/*.json` - AI conversation logs (JSON)
- `ai/*.md` - AI conversation logs (markdown)

### 4. Create Testbenches

Use the provided examples as templates:
```bash
# Use Trojan 11 testbench as reference
cp trojan_11/tb/tb_privilege_escalation.sv trojan_1/tb/
# Modify for your specific Trojan
```

### 5. Test in Docker

```bash
# Start interactive Docker session
./docker-run.sh

# Inside Docker:
cd /home/dev/src
./bazelisk.sh build //hw:all
```

## Key Features

### Automation Framework

- **Two-Phase Generation:** Analysis then code generation for better quality
- **Comprehensive Logging:** All AI interactions saved in JSON and Markdown
- **Configurable:** Easy to modify specs in `config.yaml`
- **Batch Processing:** Generate all Trojans sequentially
- **Error Handling:** Robust error recovery and logging

### Trojan Characteristics

- **Stealthy:** No effect on normal operation when dormant
- **Triggerable:** Specific, rare trigger conditions
- **Impactful:** Significant security compromise when active
- **Synthesizable:** All code uses synthesizable SystemVerilog
- **Documented:** Complete descriptions and AI logs

### Testing Approach

- **Phase 1:** Normal functionality verification
- **Phase 2:** Trojan activation verification
- **Automated:** Testbench templates and generators
- **Comprehensive:** Both positive and negative test cases

## Resources

### Documentation

- `SETUP.md` - Environment setup instructions
- `QUICKSTART.md` - Quick start guide
- `automation/README.md` - Framework documentation
- `Report/report_template.md` - Report template with guidance

### References

- [OpenTitan Documentation](https://opentitan.org/)
- [GHOST Framework Paper](https://arxiv.org/abs/2412.02816)
- [Claude API Docs](https://docs.anthropic.com/)
- [OpenTitan GitHub](https://github.com/lowRISC/opentitan)

### Example Code

- Trojan 11 (Privilege Escalation) - Complete example
- Trojan 6 (AES Key Exfiltration) - Implementation guide

## Troubleshooting

### API Key Not Set

```
Error: ANTHROPIC_API_KEY not set
```

**Solution:**
```bash
export ANTHROPIC_API_KEY="your-key"
# Or add to ~/.bashrc or ~/.zshrc
```

### Docker Container Not Found

```
Error: No such container: opentitan
```

**Solution:**
```bash
./docker-build.sh  # Takes 30-60 minutes
```

### OpenTitan Build Errors

**Solution:** Check `opentitan/doc/getting_started/` for build instructions

### Python Import Errors

**Solution:**
```bash
cd automation
pip install -r requirements.txt
```

## Tips

1. **Start with examples:** Review Trojan 11 and 6 before generating others
2. **Generate incrementally:** Test framework with 1-2 Trojans before batch processing
3. **Review AI logs:** Check conversation logs if generation fails
4. **Iterate prompts:** Modify `config.yaml` prompting strategies if needed
5. **Keep backups:** Original RTL files are automatically backed up
6. **Use Docker:** OpenTitan toolchain is complex, Docker simplifies setup

## Contributing

This is an academic project. To extend:

1. Add more Trojans to `config.yaml`
2. Enhance parsing logic in `rtl_parser.py`
3. Improve prompting strategies
4. Add more automation (synthesis, formal verification)

## Academic Context

**Assignment:** Automating LLMs for Hardware Trojan Insertion

**Objective:** Generate 15 unique Trojans in OpenTitan using automated AI framework

**Due:** December 15, 2025

**Requirements:**
- ✓ 15 Trojans (5 DoS, 5 leakage, 5 functionality change)
- ✓ Fully automated generation
- ✓ AI for vulnerability analysis
- ✓ All RTL, testbenches, and AI logs
-  Comprehensive report

## License

This project is for educational purposes. OpenTitan is licensed under Apache 2.0. GHOST benchmarks follow their respective license.

## Security Note

This project is for academic research and educational purposes only. The techniques described should only be used for:
- Security research
- Educational demonstrations
- Defensive security testing
- System hardening

Unauthorized insertion of hardware Trojans is illegal and unethical.

---

**Created:** November 22, 2025

**Last Updated:** November 22, 2025

**Status:** Infrastructure Complete, Ready for Trojan Generation

