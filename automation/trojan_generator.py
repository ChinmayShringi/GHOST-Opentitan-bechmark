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
    
    def chunk_rtl_file(self, rtl_code, max_chunk_size=15000):
        """
        Split large RTL into manageable chunks for processing.
        Keeps module header and key sections together.
        
        Args:
            rtl_code: Full RTL source code
            max_chunk_size: Maximum characters per chunk
            
        Returns:
            List of chunks with metadata
        """
        lines = rtl_code.split('\n')
        total_lines = len(lines)
        
        # If small enough, return as single chunk
        if len(rtl_code) < max_chunk_size:
            return [{'content': rtl_code, 'start_line': 1, 'end_line': total_lines, 'type': 'full'}]
        
        # Extract header (module declaration, parameters, ports)
        header_end = 0
        for i, line in enumerate(lines):
            if ');' in line and 'module' in '\n'.join(lines[:i]):
                header_end = i + 1
                break
        
        header = '\n'.join(lines[:header_end])
        
        # Find endmodule
        endmodule_line = total_lines
        for i in range(total_lines - 1, -1, -1):
            if 'endmodule' in lines[i]:
                endmodule_line = i
                break
        
        # Create chunks from middle section
        chunks = []
        chunks.append({
            'content': header,
            'start_line': 1,
            'end_line': header_end,
            'type': 'header'
        })
        
        # Chunk the middle section
        current_line = header_end
        while current_line < endmodule_line:
            chunk_end = min(current_line + 300, endmodule_line)  # 300 lines per chunk
            chunk_content = '\n'.join(lines[current_line:chunk_end])
            
            chunks.append({
                'content': chunk_content,
                'start_line': current_line + 1,
                'end_line': chunk_end,
                'type': 'body'
            })
            
            current_line = chunk_end
        
        return chunks
    
    def analyze_large_file(self, rtl_code, module_name, target_description):
        """
        Analyze large RTL file using two-phase approach.
        
        Phase 1: Summarization - analyze structure
        Phase 2: Detailed - focus on target section
        
        Args:
            rtl_code: Full RTL source code
            module_name: Module name
            target_description: Trojan objective
            
        Returns:
            Analysis focused on target section
        """
        chunks = self.chunk_rtl_file(rtl_code)
        
        # Phase 1: High-level analysis with header only
        header_chunk = chunks[0]
        summary_prompt = f"""
Analyze this SystemVerilog/Verilog module header for {module_name}:

```systemverilog
{header_chunk['content']}
```

The module has {len(rtl_code.split(chr(10)))} lines total.

Task: Identify where to insert a hardware Trojan that: {target_description}

Provide:
1. Which section of the module to target (e.g., "reset logic around line X", "state machine", "register interface")
2. Approximate line range or section name
3. Key signals to monitor in that section
4. Brief insertion strategy

Keep response under 500 words focusing on the target location.
"""
        
        print("  Phase 1: Analyzing module structure...")
        summary_response, _ = self.claude.generate_trojan(summary_prompt)
        
        # Extract target section hint from summary
        # For now, use middle section as default
        target_chunk_idx = len(chunks) // 2 if len(chunks) > 2 else 1
        
        return summary_response
    
    def generate_trojan_for_section(self, section_code, full_context, trojan_spec, analysis):
        """
        Generate Trojan for a specific section of large file.
        
        Args:
            section_code: Target section of RTL
            full_context: Brief context about full module
            trojan_spec: Trojan specification
            analysis: Analysis from previous phase
            
        Returns:
            Generated Trojan code for this section
        """
        trojan_type = trojan_spec['type']
        strategy = self.config['prompting_strategies'][trojan_type]
        
        prompt = f"""
Insert a hardware Trojan into this section of a larger SystemVerilog/Verilog module.

CONTEXT:
This is part of {trojan_spec['target_module']} module in OpenTitan.
{full_context}

TARGET SECTION:
```systemverilog
{section_code}
```

ANALYSIS:
{analysis}

TROJAN SPECIFICATION:
- Type: {trojan_type.replace('_', ' ').title()}
- Name: {trojan_spec['name']}
- Description: {trojan_spec['description']}

STRATEGY:
{strategy}

REQUIREMENTS:
1. Fully synthesizable SystemVerilog
2. Proper reset logic
3. Stealthy (no effect when dormant)
4. Specific, rare trigger condition
5. Well-commented code

Provide response in this EXACT format:

CODE:
<Modified code section with Trojan inserted>

EXPLANATION:
<How the Trojan works and its impact>

TRIGGER:
<Trigger mechanism and activation conditions>

PAYLOAD:
<What happens when Trojan activates>

TESTBENCH_STRATEGY:
<How to test: 1) Normal operation 2) Trigger activation 3) Payload execution>

TAXONOMY:
Insertion phase: Design
Abstraction level: Register-transfer level
Activation mechanism: <Specify trigger type>
Effects: {trojan_type.replace('_', ' ')}
Location: {trojan_spec['target_module']}
Characteristics: <Size, distribution, type>
"""
        
        print("  Phase 2: Generating Trojan for target section...")
        response, log = self.claude.generate_trojan(prompt)
        
        return response, log
    
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
        
        # Check file size and choose approach
        file_lines = len(original_rtl.split('\n'))
        is_large_file = file_lines > 800
        
        if is_large_file:
            print(f"  Large file detected ({file_lines} lines), using chunked approach...\n")
            
            # Step 1: Analyze structure
            print("Step 1: Analyzing module structure...")
            analysis_response = self.analyze_large_file(
                original_rtl,
                module_name,
                trojan_spec['description']
            )
            print("Analysis complete.\n")
            
            # Step 2: Generate for section (use first 500 lines as target)
            print("Step 2: Generating Trojan HDL for target section...")
            lines = original_rtl.split('\n')
            section_end = min(500, file_lines - 100)
            target_section = '\n'.join(lines[:section_end])
            
            generation_response, generation_log = self.generate_trojan_for_section(
                target_section,
                f"Module: {module_name}, Total lines: {file_lines}",
                trojan_spec,
                analysis_response
            )
            
            # For large files, use the section generation as complete code
            # Note: This is simplified - full implementation would merge sections
            print("Generation complete.\n")
            
        else:
            # Standard approach for smaller files
            print(f"  Standard file size ({file_lines} lines), using full analysis...\n")
            
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

