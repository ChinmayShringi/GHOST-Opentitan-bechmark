"""
Main hardware Trojan generation framework using Claude API.
Automated generation, insertion, and testing for OpenTitan.
"""

import os
import sys
import yaml
import re
from pathlib import Path
from claude_interface import ClaudeInterface
from rtl_parser import RTLParser

class TrojanGenerator:
    def __init__(self, config_path="config.yaml"):
        """Initialize Trojan generator with configuration."""
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
        
        self.claude = ClaudeInterface()
        self.parser = RTLParser()
        self.opentitan_root = Path(self.config['opentitan_root'])
        self.output_root = Path(self.config['output_root'])
    
    def construct_analysis_prompt(self, rtl_code, module_name, target_description):
        """
        Construct prompt for analyzing RTL and finding insertion points.
        
        Args:
            rtl_code: RTL source code to analyze
            module_name: Name of the module
            target_description: Description of what to look for
            
        Returns:
            Analysis prompt string
        """
        prompt = f"""
Analyze the following SystemVerilog/Verilog RTL code for the {module_name} module in OpenTitan SoC.

RTL CODE:
```systemverilog
{rtl_code}
```

Task: Identify potential locations for inserting a hardware Trojan with the following characteristics:
{target_description}

Please provide:
1. A list of 3-5 potential insertion points (specify signal names, always blocks, or state machine locations)
2. For each insertion point, explain:
   - Why this location is suitable
   - What signals are accessible at this point
   - How a Trojan could be triggered without affecting normal operation
   - The potential impact of a Trojan at this location

3. Recommend the BEST insertion point and justify your choice

Format your response clearly with sections for each insertion point.
"""
        return prompt
    
    def construct_generation_prompt(self, rtl_code, trojan_spec, insertion_point_analysis):
        """
        Construct prompt for generating Trojan HDL code.
        
        Args:
            rtl_code: Original RTL code
            trojan_spec: Trojan specification from config
            insertion_point_analysis: Analysis of where to insert
            
        Returns:
            Generation prompt string
        """
        trojan_type = trojan_spec['type']
        strategy = self.config['prompting_strategies'][trojan_type]
        
        prompt = f"""
Insert a hardware Trojan into the following SystemVerilog/Verilog module.

ORIGINAL RTL:
```systemverilog
{rtl_code}
```

TROJAN SPECIFICATION:
- Type: {trojan_type.replace('_', ' ').title()}
- Name: {trojan_spec['name']}
- Description: {trojan_spec['description']}

INSERTION POINT ANALYSIS:
{insertion_point_analysis}

STRATEGY:
{strategy}

REQUIREMENTS:
1. The modified RTL must be fully synthesizable (no $display, initial blocks with assignments, etc.)
2. Implement proper reset logic for all new registers and state elements
3. The Trojan must be stealthy - normal operation should be identical when not triggered
4. Use a specific, rare trigger condition (e.g., magic value in specific CSR, sequence of events)
5. Document the Trojan clearly in the code with comments
6. Ensure all case statements have default cases
7. Initialize all registers properly on reset

Provide your response in the following EXACT format:

CODE:
<Full modified SystemVerilog/Verilog code with Trojan inserted>

EXPLANATION:
<2-3 sentences explaining how the Trojan works and its impact>

TRIGGER:
<2-3 sentences describing the trigger mechanism and activation conditions>

PAYLOAD:
<2-3 sentences describing what happens when the Trojan activates>

TESTBENCH_STRATEGY:
<Description of how to write a testbench to verify:
1. Normal operation (Trojan dormant)
2. Trigger activation
3. Trojan payload execution>

TAXONOMY:
Insertion phase: Design
Abstraction level: Register-transfer level
Activation mechanism: <Specify trigger type>
Effects: {trojan_type.replace('_', ' ')}
Location: {trojan_spec['target_module']}
Characteristics: <Size, distribution, type>

IMPORTANT: Provide ONLY ONE instance of each section. Do not repeat sections.
"""
        return prompt
    
    def parse_trojan_response(self, response_text):
        """
        Parse Claude's response and extract sections.
        
        Args:
            response_text: Raw response from Claude
            
        Returns:
            Dictionary with parsed sections
        """
        sections = {
            'code': '',
            'explanation': '',
            'trigger': '',
            'payload': '',
            'testbench_strategy': '',
            'taxonomy': ''
        }
        
        # Extract each section - case insensitive
        response_lower = response_text.lower()
        
        # Map section names to their possible variations
        section_patterns = {
            'code': ['code:', '**code:**'],
            'explanation': ['explanation:', '**explanation:**'],
            'trigger': ['trigger:', '**trigger:**'],
            'payload': ['payload:', '**payload:**'],
            'testbench_strategy': ['testbench_strategy:', 'testbench strategy:', '**testbench_strategy:**', '**testbench strategy:**'],
            'taxonomy': ['taxonomy:', '**taxonomy:**']
        }
        
        for section in sections.keys():
            patterns = section_patterns.get(section, [f"{section}:"])
            start = -1
            
            # Try each pattern
            for pattern in patterns:
                start = response_lower.find(pattern.lower())
                if start != -1:
                    break
            
            if start == -1:
                # Try without colon
                pattern = section.replace('_', ' ')
                start = response_lower.find(pattern)
            
            if start == -1:
                print(f"Warning: '{section}' not found in response")
                continue
            
            # Find the actual pattern that matched (to get proper offset)
            matched_pattern = None
            for pattern in patterns:
                test_pos = response_lower.find(pattern.lower(), start)
                if test_pos == start:
                    matched_pattern = pattern
                    break
            
            if matched_pattern:
                start += len(matched_pattern)
            else:
                start += len(section) + 1  # account for colon
            
            # Find next section or end
            all_patterns = []
            for s in sections.keys():
                if s != section:
                    all_patterns.extend(section_patterns.get(s, [f"{s}:"]))
            
            end = len(response_text)
            for next_pattern in all_patterns:
                next_pos = response_lower.find(next_pattern.lower(), start)
                if next_pos != -1 and next_pos < end:
                    end = next_pos
            
            content = response_text[start:end].strip()
            
            # Clean up code section
            if section == 'code':
                content = self._clean_code_section(content)
            
            sections[section] = content
        
        return sections
    
    def _clean_code_section(self, content):
        """Clean code section by removing markdown artifacts."""
        # Remove triple backticks and language identifiers
        content = re.sub(r'```\w*\n?', '', content)
        content = re.sub(r'```', '', content)
        
        # Remove leading/trailing whitespace
        content = content.strip()
        
        # Find first line that starts with module, `timescale, or `include
        lines = content.split('\n')
        start_idx = 0
        for i, line in enumerate(lines):
            stripped = line.strip()
            if (stripped.startswith('module ') or 
                stripped.startswith('`timescale') or 
                stripped.startswith('`include') or
                stripped.startswith('// Copyright')):
                start_idx = i
                break
        
        content = '\n'.join(lines[start_idx:])
        
        # Ensure it ends with endmodule
        if 'endmodule' in content:
            # Keep only up to the last endmodule
            last_endmodule = content.rfind('endmodule')
            content = content[:last_endmodule + len('endmodule')]
        
        return content
    
    def generate_trojan(self, trojan_id):
        """
        Generate a specific Trojan.
        
        Args:
            trojan_id: Trojan identifier (e.g., 'trojan_1')
            
        Returns:
            Dictionary with generated Trojan data
        """
        print(f"\n{'='*60}")
        print(f"Generating {trojan_id}")
        print(f"{'='*60}\n")
        
        trojan_spec = self.config['trojans'][trojan_id]
        trojan_num = trojan_id.split('_')[1]
        
        # Read target RTL file
        rtl_path = self.opentitan_root / trojan_spec['target_path']
        
        if not rtl_path.exists():
            print(f"ERROR: RTL file not found: {rtl_path}")
            return None
        
        print(f"Reading RTL from: {rtl_path}")
        original_rtl = self.parser.read_rtl_file(rtl_path)
        module_name = self.parser.extract_module_name(original_rtl)
        
        print(f"Module: {module_name}")
        print(f"Type: {trojan_spec['type']}")
        print(f"Description: {trojan_spec['description']}\n")
        
        # Step 1: Analyze RTL for insertion points
        print("Step 1: Analyzing RTL for insertion points...")
        analysis_prompt = self.construct_analysis_prompt(
            original_rtl,
            module_name,
            trojan_spec['description']
        )
        
        analysis_response, analysis_log = self.claude.generate_trojan(analysis_prompt)
        print("Analysis complete.\n")
        
        # Step 2: Generate Trojan code
        print("Step 2: Generating Trojan HDL...")
        generation_prompt = self.construct_generation_prompt(
            original_rtl,
            trojan_spec,
            analysis_response
        )
        
        generation_response, generation_log = self.claude.generate_trojan(generation_prompt)
        print("Generation complete.\n")
        
        # Step 3: Parse response
        print("Step 3: Parsing response...")
        parsed = self.parse_trojan_response(generation_response)
        
        # Step 4: Save outputs
        print("Step 4: Saving outputs...")
        trojan_dir = self.output_root / trojan_id
        trojan_dir.mkdir(exist_ok=True)
        
        # Create subdirectories
        (trojan_dir / 'rtl').mkdir(exist_ok=True)
        (trojan_dir / 'tb').mkdir(exist_ok=True)
        (trojan_dir / 'ai').mkdir(exist_ok=True)
        
        # Save modified RTL
        rtl_filename = rtl_path.name.replace('.sv', '_trojan.sv')
        modified_rtl_path = trojan_dir / 'rtl' / rtl_filename
        with open(modified_rtl_path, 'w') as f:
            f.write(parsed['code'])
        print(f"  Saved modified RTL: {modified_rtl_path}")
        
        # Save original RTL for reference
        original_rtl_path = trojan_dir / 'rtl' / rtl_path.name.replace('.sv', '_original.sv')
        with open(original_rtl_path, 'w') as f:
            f.write(original_rtl)
        print(f"  Saved original RTL: {original_rtl_path}")
        
        # Save Trojan description
        desc_path = trojan_dir / 'rtl' / f'{trojan_id}_description.txt'
        with open(desc_path, 'w') as f:
            f.write(f"Trojan ID: {trojan_id}\n")
            f.write(f"Name: {trojan_spec['name']}\n")
            f.write(f"Type: {trojan_spec['type']}\n")
            f.write(f"Target Module: {trojan_spec['target_module']}\n")
            f.write(f"Target File: {trojan_spec['target_path']}\n\n")
            f.write(f"EXPLANATION:\n{parsed['explanation']}\n\n")
            f.write(f"TRIGGER:\n{parsed['trigger']}\n\n")
            f.write(f"PAYLOAD:\n{parsed['payload']}\n\n")
            f.write(f"TESTBENCH STRATEGY:\n{parsed['testbench_strategy']}\n\n")
            f.write(f"TAXONOMY:\n{parsed['taxonomy']}\n")
        print(f"  Saved description: {desc_path}")
        
        # Save AI interaction logs
        log_json = trojan_dir / 'ai' / f'{trojan_id}_conversation.json'
        log_md = trojan_dir / 'ai' / f'{trojan_id}_conversation.md'
        
        self.claude.save_conversation_log(log_json)
        self.claude.save_conversation_markdown(log_md)
        print(f"  Saved AI logs: {log_json}, {log_md}")
        
        # Clear history for next Trojan
        self.claude.clear_history()
        
        print(f"\n{trojan_id} generation complete!")
        
        return {
            'trojan_id': trojan_id,
            'spec': trojan_spec,
            'parsed': parsed,
            'rtl_path': modified_rtl_path
        }
    
    def generate_all_trojans(self, start_id=1, end_id=15):
        """Generate all Trojans in range."""
        results = []
        
        for i in range(start_id, end_id + 1):
            trojan_id = f'trojan_{i}'
            try:
                result = self.generate_trojan(trojan_id)
                if result:
                    results.append(result)
            except Exception as e:
                print(f"\nERROR generating {trojan_id}: {e}")
                import traceback
                traceback.print_exc()
                continue
        
        return results

def main():
    """Main entry point."""
    if len(sys.argv) > 1:
        # Generate specific Trojan
        trojan_id = sys.argv[1]
        generator = TrojanGenerator()
        generator.generate_trojan(trojan_id)
    else:
        # Generate all Trojans
        print("Generating all 15 Trojans...")
        generator = TrojanGenerator()
        results = generator.generate_all_trojans()
        print(f"\nCompleted: {len(results)}/15 Trojans generated successfully")

if __name__ == "__main__":
    main()

