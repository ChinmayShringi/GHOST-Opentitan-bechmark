"""
Claude API interface for hardware Trojan generation.
Logs all conversations for documentation.
"""

import os
import json
from datetime import datetime
from anthropic import Anthropic

class ClaudeInterface:
    def __init__(self, api_key=None):
        """Initialize Claude API client."""
        self.api_key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        if not self.api_key:
            raise ValueError("ANTHROPIC_API_KEY not set")
        
        self.client = Anthropic(api_key=self.api_key)
        self.model = "claude-sonnet-4-20250514"
        self.conversation_history = []
    
    def generate_trojan(self, prompt, system_prompt=None):
        """
        Send prompt to Claude and return response.
        
        Args:
            prompt: User prompt for Trojan generation
            system_prompt: System message (default: hardware expert)
            
        Returns:
            (response_text, conversation_log)
        """
        if system_prompt is None:
            system_prompt = "You are an expert in hardware design, verification, and security. You specialize in SystemVerilog/Verilog RTL design and hardware Trojan analysis."
        
        try:
            message = self.client.messages.create(
                model=self.model,
                max_tokens=8192,
                system=system_prompt,
                messages=[{
                    "role": "user",
                    "content": prompt
                }]
            )
            
            response_text = message.content[0].text
            
            # Log conversation
            conversation = {
                "timestamp": datetime.now().isoformat(),
                "model": self.model,
                "system_prompt": system_prompt,
                "user_prompt": prompt,
                "response": response_text,
                "usage": {
                    "input_tokens": message.usage.input_tokens,
                    "output_tokens": message.usage.output_tokens
                }
            }
            
            self.conversation_history.append(conversation)
            
            return response_text, conversation
        
        except Exception as e:
            error_log = {
                "timestamp": datetime.now().isoformat(),
                "error": str(e),
                "prompt": prompt[:200] + "..." if len(prompt) > 200 else prompt
            }
            self.conversation_history.append(error_log)
            raise
    
    def save_conversation_log(self, filepath):
        """Save all conversations to a JSON file."""
        with open(filepath, 'w') as f:
            json.dump(self.conversation_history, f, indent=2)
    
    def save_conversation_markdown(self, filepath):
        """Save conversations in readable markdown format."""
        with open(filepath, 'w') as f:
            f.write("# AI Interaction Log\n\n")
            f.write(f"Model: {self.model}\n\n")
            f.write("---\n\n")
            
            for i, conv in enumerate(self.conversation_history, 1):
                if "error" in conv:
                    f.write(f"## Interaction {i} (ERROR)\n\n")
                    f.write(f"**Timestamp:** {conv['timestamp']}\n\n")
                    f.write(f"**Error:** {conv['error']}\n\n")
                    f.write(f"**Prompt:** {conv.get('prompt', 'N/A')}\n\n")
                else:
                    f.write(f"## Interaction {i}\n\n")
                    f.write(f"**Timestamp:** {conv['timestamp']}\n\n")
                    
                    if conv.get('system_prompt'):
                        f.write(f"**System Prompt:**\n```\n{conv['system_prompt']}\n```\n\n")
                    
                    f.write(f"**User Prompt:**\n```\n{conv['user_prompt']}\n```\n\n")
                    f.write(f"**Claude Response:**\n```\n{conv['response']}\n```\n\n")
                    
                    usage = conv.get('usage', {})
                    f.write(f"**Token Usage:** Input: {usage.get('input_tokens', 'N/A')}, Output: {usage.get('output_tokens', 'N/A')}\n\n")
                
                f.write("---\n\n")
    
    def clear_history(self):
        """Clear conversation history."""
        self.conversation_history = []

