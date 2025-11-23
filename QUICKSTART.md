# Quick Start Guide

## Prerequisites

1. Docker installed
2. Python 3.8+
3. Claude API key from Anthropic

## Setup Steps

### 1. Set API Key

```bash
export ANTHROPIC_API_KEY="your-anthropic-api-key-here"
```

To make it persistent, add to `~/.bashrc` or `~/.zshrc`:
```bash
echo 'export ANTHROPIC_API_KEY="your-key-here"' >> ~/.zshrc
source ~/.zshrc
```

### 2. Install Python Dependencies

```bash
cd automation
pip install -r requirements.txt
```

### 3. Build OpenTitan Docker Container (Optional but Recommended)

This takes 30-60 minutes:
```bash
./docker-build.sh
```

## Generating Trojans

### Generate Single Trojan

```bash
cd automation
python trojan_generator.py trojan_1
```

This will:
1. Analyze the target OpenTitan module
2. Generate Trojan HDL code
3. Save modified RTL to `trojan_1/rtl/`
4. Save AI conversation logs to `trojan_1/ai/`
5. Create Trojan description document

### Generate All 15 Trojans

```bash
cd automation
python trojan_generator.py
```

This will generate all Trojans sequentially. Takes approximately 30-60 minutes depending on API rate limits.

## Workflow Per Trojan

After generation, for each Trojan:

### 1. Review Generated Code

```bash
cat trojan_N/rtl/*_trojan.sv
cat trojan_N/rtl/trojan_N_description.txt
```

### 2. Create Testbench

Either use the testbench generator:
```bash
cd automation
python -c "
from testbench_generator import TestbenchGenerator
gen = TestbenchGenerator()
# Generate testbench...
"
```

Or write manually based on the testbench strategy in the description.

### 3. Copy to OpenTitan

```bash
cp trojan_N/rtl/*_trojan.sv opentitan/hw/.../<original_location>/
```

### 4. Build and Test

```bash
./docker-run.sh "cd /home/dev/src && ./bazelisk.sh build //hw:all"
./docker-simulate.sh //hw/ip/<module>:tests
```

### 5. Run Exploit Test

```bash
cd trojan_N/tb
# Compile and run testbench
iverilog -o test_sim ../rtl/*_trojan.sv tb_*.sv
vvp test_sim
```

## Directory Structure After Generation

```
GHOSTassignment/
├── trojan_1/
│   ├── rtl/
│   │   ├── module_trojan.sv
│   │   ├── module_original.sv
│   │   └── trojan_1_description.txt
│   ├── tb/
│   │   └── (testbenches you create)
│   └── ai/
│       ├── trojan_1_conversation.json
│       └── trojan_1_conversation.md
├── trojan_2/
│   └── ...
...
├── trojan_15/
│   └── ...
└── Report/
    └── (final report)
```

## Troubleshooting

### API Key Errors

```
ValueError: ANTHROPIC_API_KEY not set
```

**Solution**: Export your API key:
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

### RTL File Not Found

```
ERROR: RTL file not found: opentitan/hw/...
```

**Solution**: Ensure OpenTitan is cloned and paths in `automation/config.yaml` are correct.

### Docker Container Issues

```
Error response from daemon: No such container...
```

**Solution**: Build the container first:
```bash
./docker-build.sh
```

## Next Steps

1. Generate all 15 Trojans
2. Create testbenches for each
3. Validate each Trojan works (normal + exploit tests)
4. Document results in Report/
5. Create final report with all findings

## Tips

- Start with one Trojan to validate the workflow
- Review AI conversation logs if generation fails
- Modify `automation/config.yaml` to adjust targets or strategies
- Use `docker-run.sh` for interactive OpenTitan environment
- Keep original RTL backups (automatically created as `*_original.sv`)

## Support

Check these resources:
- `SETUP.md` - Detailed setup instructions
- `automation/README.md` - Framework documentation
- `opentitan/doc/` - OpenTitan documentation
- `ghost/README.md` - GHOST framework reference

