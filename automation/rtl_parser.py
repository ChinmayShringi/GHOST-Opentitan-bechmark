"""
RTL parsing and manipulation utilities for Verilog/SystemVerilog.
"""

import re
import os
from pathlib import Path

class RTLParser:
    def __init__(self):
        """Initialize RTL parser."""
        pass
    
    def read_rtl_file(self, filepath):
        """Read RTL file and return content."""
        with open(filepath, 'r') as f:
            return f.read()
    
    def extract_module_name(self, rtl_code):
        """Extract module name from RTL code."""
        match = re.search(r'module\s+(\w+)', rtl_code)
        if match:
            return match.group(1)
        return None
    
    def extract_ports(self, rtl_code):
        """Extract port declarations from RTL code."""
        # Find module declaration
        module_match = re.search(r'module\s+\w+\s*\((.*?)\);', rtl_code, re.DOTALL)
        if not module_match:
            return []
        
        port_section = module_match.group(1)
        
        # Extract individual ports (simplified)
        ports = []
        for line in port_section.split('\n'):
            line = line.strip()
            if line and not line.startswith('//'):
                # Remove comments
                line = re.sub(r'//.*$', '', line)
                if 'input' in line or 'output' in line or 'inout' in line:
                    ports.append(line.strip(' ,'))
        
        return ports
    
    def find_insertion_points(self, rtl_code, context=""):
        """
        Identify potential Trojan insertion points in RTL.
        
        Args:
            rtl_code: RTL source code
            context: Additional context (e.g., "privilege control", "crypto operations")
            
        Returns:
            List of potential insertion points with line numbers and descriptions
        """
        insertion_points = []
        lines = rtl_code.split('\n')
        
        # Look for always blocks
        for i, line in enumerate(lines):
            if re.search(r'always\s*@', line):
                insertion_points.append({
                    'line': i + 1,
                    'type': 'always_block',
                    'context': line.strip(),
                    'description': 'Sequential logic block'
                })
            
            # Look for state machines
            if re.search(r'case\s*\(.*state', line, re.IGNORECASE):
                insertion_points.append({
                    'line': i + 1,
                    'type': 'state_machine',
                    'context': line.strip(),
                    'description': 'State machine logic'
                })
            
            # Look for register assignments
            if re.search(r'<=\s*\w+', line) and 'always' not in line:
                if 'key' in line.lower() or 'data' in line.lower() or 'priv' in line.lower():
                    insertion_points.append({
                        'line': i + 1,
                        'type': 'register_assignment',
                        'context': line.strip(),
                        'description': 'Sensitive register assignment'
                    })
        
        return insertion_points
    
    def insert_trojan_code(self, original_rtl, trojan_code, insertion_line=None):
        """
        Insert Trojan code into RTL at specified location.
        
        Args:
            original_rtl: Original RTL source
            trojan_code: Trojan code to insert
            insertion_line: Line number to insert (None for smart detection)
            
        Returns:
            Modified RTL with Trojan inserted
        """
        lines = original_rtl.split('\n')
        
        if insertion_line is None:
            # Find appropriate insertion point (before endmodule)
            for i in range(len(lines) - 1, -1, -1):
                if 'endmodule' in lines[i]:
                    insertion_line = i
                    break
        
        if insertion_line is not None:
            trojan_lines = trojan_code.split('\n')
            # Insert with proper indentation
            indent = self._get_indentation(lines, insertion_line)
            indented_trojan = [indent + line if line.strip() else line 
                             for line in trojan_lines]
            
            lines[insertion_line:insertion_line] = indented_trojan
        
        return '\n'.join(lines)
    
    def _get_indentation(self, lines, line_num):
        """Get indentation level from surrounding code."""
        if line_num >= len(lines):
            return '  '
        
        # Check previous lines for indentation pattern
        for i in range(max(0, line_num - 5), line_num):
            if lines[i].strip():
                match = re.match(r'^(\s*)', lines[i])
                if match:
                    return match.group(1)
        
        return '  '  # Default indentation
    
    def extract_signals(self, rtl_code):
        """Extract signal declarations from RTL."""
        signals = []
        
        # Find wire/reg declarations
        wire_pattern = r'(wire|reg|logic)\s+(\[.*?\])?\s*(\w+)'
        for match in re.finditer(wire_pattern, rtl_code):
            sig_type = match.group(1)
            sig_width = match.group(2) if match.group(2) else '[0:0]'
            sig_name = match.group(3)
            signals.append({
                'type': sig_type,
                'width': sig_width,
                'name': sig_name
            })
        
        return signals
    
    def find_rtl_files(self, directory, pattern="*.sv"):
        """Find all RTL files in directory recursively."""
        path = Path(directory)
        if pattern.endswith('.sv'):
            files = list(path.rglob('*.sv')) + list(path.rglob('*.v'))
        else:
            files = list(path.rglob(pattern))
        
        return [str(f) for f in files]
    
    def backup_file(self, filepath):
        """Create backup of original RTL file."""
        backup_path = filepath + '.original'
        if not os.path.exists(backup_path):
            with open(filepath, 'r') as src:
                with open(backup_path, 'w') as dst:
                    dst.write(src.read())
        return backup_path
    
    def restore_from_backup(self, filepath):
        """Restore file from backup."""
        backup_path = filepath + '.original'
        if os.path.exists(backup_path):
            with open(backup_path, 'r') as src:
                with open(filepath, 'w') as dst:
                    dst.write(src.read())
            return True
        return False

