# Hardware Trojan Automation Framework

Automated framework for generating, inserting, and testing hardware Trojans in OpenTitan using Claude AI.

## Overview

This framework automates the GHOST approach for OpenTitan, using Claude (Anthropic) as the LLM backend.

## Components

### Core Modules

- `trojan_generator.py` - Main automation framework
- `claude_interface.py` - Claude API wrapper with conversation logging
- `rtl_parser.py` - Verilog/SystemVerilog parsing and manipulation
- `testbench_generator.py` - Automated testbench generation
- `config.yaml` - Configuration for all 15 Trojans

### Configuration

Edit `config.yaml` to customize:
- Trojan targets and specifications
- OpenTitan module paths
- Prompting strategies
- Claude API settings

## Installation

```bash
pip install -r requirements.txt
```

Set your Claude API key:
```bash
export ANTHROPIC_API_KEY="your-key-here"
```

## Usage

### Generate Single Trojan

```bash
cd automation
python trojan_generator.py trojan_1
```

### Generate All Trojans

```bash
python trojan_generator.py
```

### Generate Specific Range

Edit `trojan_generator.py` and modify the `generate_all_trojans()` call.

## Output Structure

Each Trojan generates:

```
trojan_N/
├── rtl/
│   ├── module_name_trojan.sv     # Modified RTL with Trojan
│   ├── module_name_original.sv   # Original RTL
│   └── trojan_N_description.txt  # Trojan documentation
├── tb/
│   └── tb_module_name.sv         # Testbench (manual or generated)
└── ai/
    ├── trojan_N_conversation.json  # Full conversation log
    └── trojan_N_conversation.md    # Human-readable log
```

## Workflow

1. **Analysis Phase**: Claude analyzes target RTL module and identifies insertion points
2. **Generation Phase**: Claude generates Trojan HDL based on specification
3. **Parsing Phase**: Extract code, explanation, trigger, payload from response
4. **Output Phase**: Save modified RTL, documentation, and AI logs
5. **Testing Phase**: Generate and run testbenches (manual step)

## Trojan Types

### Denial of Service (Trojans 1-5)
- Clock gating, reset loops, bus lockup, crypto halt, interrupt storms

### Information Leakage (Trojans 6-10)
- Key exfiltration, memory dumps, side-channel amplification, debug backdoors

### Change of Functionality (Trojans 11-15)
- Privilege escalation, signature bypass, boot hijack, protection bypass, RNG manipulation

## Testing

After generating Trojans:

1. Copy modified RTL to OpenTitan directory
2. Build OpenTitan in Docker
3. Run normal testbenches to verify no regression
4. Run exploit testbenches to verify Trojan activation

See parent directory's `docker-*.sh` scripts for Docker operations.

## Troubleshooting

### API Errors

- Check `ANTHROPIC_API_KEY` is set
- Verify API quota/limits
- Check internet connection

### Parsing Errors

- Review `ai/*.json` logs to see raw Claude output
- Adjust parsing logic in `parse_trojan_response()` if needed

### RTL Errors

- Verify OpenTitan paths in `config.yaml`
- Check that RTL files exist at specified locations
- Ensure OpenTitan repository is up to date

## Extending

To add more Trojans:

1. Add entry to `config.yaml` under `trojans:`
2. Run `python trojan_generator.py trojan_16`

To modify prompting strategies:

1. Edit `prompting_strategies` in `config.yaml`
2. Or modify `construct_generation_prompt()` in `trojan_generator.py`

## Notes

- All AI conversations are logged for documentation
- Original RTL files are preserved
- Framework supports iterative refinement
- Testbenches can be generated automatically or written manually

