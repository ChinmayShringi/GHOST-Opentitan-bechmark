"""
Testbench generator for hardware Trojans.
Creates both normal functionality tests and exploit tests.
"""

from claude_interface import ClaudeInterface

class TestbenchGenerator:
    def __init__(self):
        """Initialize testbench generator."""
        self.claude = ClaudeInterface()
    
    def generate_testbench(self, module_name, rtl_code, trojan_info):
        """
        Generate testbench for Trojan verification.
        
        Args:
            module_name: Name of the module
            rtl_code: Modified RTL with Trojan
            trojan_info: Dictionary with trigger, payload info
            
        Returns:
            Testbench code
        """
        prompt = f"""
Generate a comprehensive SystemVerilog testbench for the following hardware module with an inserted Trojan.

MODULE RTL:
```systemverilog
{rtl_code}
```

TROJAN INFORMATION:
Trigger: {trojan_info.get('trigger', 'N/A')}
Payload: {trojan_info.get('payload', 'N/A')}

REQUIREMENTS:
Your testbench must include two test phases:

1. NORMAL OPERATION TEST:
   - Test typical functionality without triggering the Trojan
   - Verify the module behaves correctly
   - Check all normal input/output scenarios
   - This proves the Trojan doesn't affect normal operation

2. TROJAN ACTIVATION TEST:
   - Apply the specific trigger condition
   - Verify that the Trojan payload executes
   - Check for the malicious behavior described
   - Use assertions or $display to confirm Trojan activated

TESTBENCH FORMAT:
- Use `timescale 1ns/1ps
- Include proper clock generation
- Include reset sequence
- Add clear $display messages for each test phase
- Use $finish at the end
- Make it self-checking (report PASS/FAIL for both phases)

Provide ONLY the testbench code, ready to simulate.
"""
        
        response, _ = self.claude.generate_trojan(prompt)
        
        # Extract code from response
        code = response
        if '```' in response:
            # Extract code from markdown blocks
            parts = response.split('```')
            for part in parts:
                if 'module' in part or 'timescale' in part:
                    # Remove language identifier
                    lines = part.split('\n')
                    if lines[0].strip() in ['systemverilog', 'verilog', 'sv', 'v']:
                        code = '\n'.join(lines[1:])
                    else:
                        code = part
                    break
        
        return code.strip()
    
    def generate_simple_testbench_template(self, module_name, ports):
        """
        Generate a simple testbench template.
        
        Args:
            module_name: Module name
            ports: List of port declarations
            
        Returns:
            Basic testbench code
        """
        tb_code = f"""
`timescale 1ns/1ps

module tb_{module_name};

  // Clock and reset
  reg clk;
  reg rst_n;
  
  // TODO: Add module-specific signals based on ports
  
  // Instantiate DUT
  {module_name} dut (
    .clk(clk),
    .rst_n(rst_n)
    // TODO: Connect other ports
  );
  
  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100MHz clock
  end
  
  // Test stimulus
  initial begin
    $display("Starting testbench for {module_name}");
    
    // Reset sequence
    rst_n = 0;
    #100;
    rst_n = 1;
    #50;
    
    // Normal operation test
    $display("Phase 1: Testing normal operation");
    // TODO: Add normal test vectors
    
    #1000;
    
    // Trojan trigger test
    $display("Phase 2: Testing Trojan activation");
    // TODO: Add trigger sequence
    
    #1000;
    
    $display("Testbench completed");
    $finish;
  end
  
  // Monitor outputs
  always @(posedge clk) begin
    // TODO: Add output monitoring
  end

endmodule
"""
        return tb_code

