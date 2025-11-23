# OpenTitan Hardware Trojan Automation Setup

## Repository Structure

```
GHOSTassignment/
├── ghost/                  # GHOST benchmarks repository
├── opentitan/              # OpenTitan SoC repository
├── trojan_1/ through trojan_15/
│   ├── rtl/               # Modified RTL files
│   ├── tb/                # Testbenches
│   └── ai/                # AI interaction logs
├── Report/                # Final report
├── automation/            # Trojan automation framework
├── docker-build.sh        # Build OpenTitan Docker container
├── docker-run.sh          # Run OpenTitan Docker interactively
└── docker-simulate.sh     # Run OpenTitan simulations
```

## Prerequisites

- Docker (for OpenTitan toolchain)
- Python 3.8+
- Claude API key (Anthropic)

## Setup Instructions

### 1. Clone Repositories

Repositories are already cloned:
- GHOST: https://github.com/NMSU-PEARL/GHOST_benchmarks
- OpenTitan: https://github.com/lowRISC/opentitan

### 2. Build Docker Container

Build the OpenTitan Docker container (contains all necessary tools):

```bash
./docker-build.sh
```

This may take 30-60 minutes as it installs Verilator, Yosys, and other EDA tools.

### 3. Configure API Keys

Set your Claude API key:

```bash
export ANTHROPIC_API_KEY="your-api-key-here"
```

Add to `~/.bashrc` or `~/.zshrc` to persist.

### 4. Install Python Dependencies

```bash
pip install anthropic pyyaml
```

## Using Docker Helper Scripts

### Interactive Shell

```bash
./docker-run.sh
```

### Run Command

```bash
./docker-run.sh "cd hw && fusesoc --cores-root=. run --target=sim --setup --build lowrisc:systems:top_earlgrey_verilator"
```

### Run Tests

```bash
./docker-simulate.sh //hw:all
```

## Automation Framework

The `automation/` directory contains Python scripts for automated Trojan generation:

- `trojan_generator.py` - Main framework
- `claude_interface.py` - Claude API wrapper
- `rtl_parser.py` - Verilog/SystemVerilog parsing
- `config.yaml` - Configuration file

## Workflow

1. Analyze OpenTitan modules using Claude
2. Identify vulnerable insertion points
3. Generate Trojan HDL code
4. Insert into OpenTitan RTL
5. Generate testbenches
6. Build and simulate in Docker
7. Validate functionality
8. Document results

## OpenTitan Key Modules

Target modules for Trojan insertion:

- `hw/ip/rv_core_ibex/` - RISC-V CPU core
- `hw/ip/aes/` - AES crypto accelerator
- `hw/ip/hmac/` - HMAC engine
- `hw/ip/keymgr/` - Key manager
- `hw/ip/otp_ctrl/` - OTP controller
- `hw/top_earlgrey/` - Top-level integration

## References

- OpenTitan: https://opentitan.org/
- GHOST Framework: https://github.com/NMSU-PEARL/GHOST_benchmarks
- Claude API: https://docs.anthropic.com/

