#!/usr/bin/env python3
"""
Comprehensive MCP Server Testing Suite
Tests building, running, and basic functionality of all MCP servers
"""

import subprocess
import json
import os
import time
import sys
from pathlib import Path

# MCP servers configuration
MCP_SERVERS = {
    'mcp-aws': {
        'type': 'python',
        'dockerfile': 'Dockerfile',
        'test_cmd': '{"jsonrpc":"2.0","method":"tools/list","id":1}',
        'env': {'AWS_ACCESS_KEY_ID': 'test', 'AWS_SECRET_ACCESS_KEY': 'test'}
    },
    'mcp-notion': {
        'type': 'node',
        'dockerfile': 'Dockerfile',
        'test_cmd': '{"jsonrpc":"2.0","method":"tools/list","id":1}',
        'env': {'NOTION_API_KEY': 'secret_test_123'}
    },
    'mcp-google-workspace': {
        'type': 'python',
        'dockerfile': 'Dockerfile',
        'test_cmd': '{"jsonrpc":"2.0","method":"tools/list","id":1}',
        'env': {'GOOGLE_APPLICATION_CREDENTIALS': '/tmp/test-creds.json'}
    },
    'mcp-google-sheets': {
        'type': 'python',
        'dockerfile': '../dockerfiles/Dockerfile.mcp-google-sheets',
        'test_cmd': '{"jsonrpc":"2.0","method":"tools/list","id":1}',
        'env': {'GOOGLE_SERVICE_ACCOUNT_JSON': '{}'}
    },
    'mcp-gdrive': {
        'type': 'node',
        'dockerfile': '../dockerfiles/Dockerfile.mcp-gdrive',
        'test_cmd': '{"jsonrpc":"2.0","method":"tools/list","id":1}',
        'env': {'GOOGLE_APPLICATION_CREDENTIALS': '/tmp/test-creds.json'}
    },
    'mcp-slack': {
        'type': 'go',
        'dockerfile': 'Dockerfile',
        'test_cmd': '{"jsonrpc":"2.0","method":"tools/list","id":1}',
        'env': {'SLACK_BOT_TOKEN': 'xoxb-test', 'SLACK_APP_TOKEN': 'xapp-test'}
    },
    'mcp-pdf-reader': {
        'type': 'python',
        'dockerfile': 'Dockerfile',
        'test_cmd': '{"jsonrpc":"2.0","method":"tools/list","id":1}',
        'env': {}
    },
    'mcp-cloudflare': {
        'type': 'node',
        'dockerfile': 'Dockerfile',
        'test_cmd': '{"jsonrpc":"2.0","method":"tools/list","id":1}',
        'env': {'CLOUDFLARE_API_TOKEN': 'test_token'}
    },
    'mcp-stripe': {
        'type': 'node',
        'dockerfile': 'Dockerfile',
        'test_cmd': '{"jsonrpc":"2.0","method":"tools/list","id":1}',
        'env': {'STRIPE_API_KEY': 'sk_test_123'}
    },
    'mcp-shopify': {
        'type': 'node',
        'dockerfile': 'Dockerfile',
        'test_cmd': '{"jsonrpc":"2.0","method":"tools/list","id":1}',
        'env': {}
    }
}

class MCPServerTester:
    def __init__(self):
        self.base_path = Path('/Users/andreihasna/Missions/beepmedia/mission-mcps')
        self.results = {}
        
    def run_command(self, cmd, cwd=None, capture=True):
        """Run shell command"""
        try:
            if capture:
                result = subprocess.run(cmd, shell=True, cwd=cwd, 
                                      capture_output=True, text=True)
                return result.returncode == 0, result.stdout, result.stderr
            else:
                result = subprocess.run(cmd, shell=True, cwd=cwd)
                return result.returncode == 0, "", ""
        except Exception as e:
            return False, "", str(e)
    
    def build_docker_image(self, server_name, config):
        """Build Docker image for MCP server"""
        print(f"\n📦 Building {server_name}...")
        
        repo_path = self.base_path / 'repos' / server_name
        dockerfile = config['dockerfile']
        
        # Handle relative dockerfile paths
        if dockerfile.startswith('../'):
            dockerfile_path = self.base_path / dockerfile.replace('../', '')
        else:
            dockerfile_path = repo_path / dockerfile
        
        # Check if Dockerfile exists
        if not dockerfile_path.exists():
            print(f"❌ Dockerfile not found: {dockerfile_path}")
            return False
            
        # Build command
        build_cmd = f"docker build -t {server_name}:test -f {dockerfile_path} {repo_path}"
        
        success, stdout, stderr = self.run_command(build_cmd)
        
        if success:
            print(f"✅ Successfully built {server_name}")
        else:
            print(f"❌ Failed to build {server_name}")
            print(f"Error: {stderr}")
            
        return success
    
    def test_mcp_stdio(self, server_name, config):
        """Test MCP server in stdio mode"""
        print(f"\n🧪 Testing {server_name} stdio mode...")
        
        # Create environment string
        env_vars = ' '.join([f'-e {k}={v}' for k, v in config['env'].items()])
        
        # Run container and send test command
        test_cmd = config['test_cmd']
        run_cmd = f"echo '{test_cmd}' | docker run -i --rm {env_vars} {server_name}:test"
        
        success, stdout, stderr = self.run_command(run_cmd)
        
        if success and stdout:
            try:
                # Try to parse JSON response
                lines = stdout.strip().split('\n')
                for line in lines:
                    if line.strip().startswith('{'):
                        response = json.loads(line)
                        if 'result' in response or 'error' in response:
                            print(f"✅ {server_name} stdio test passed")
                            return True
            except:
                pass
        
        print(f"❌ {server_name} stdio test failed")
        return False
    
    def test_server(self, server_name, config):
        """Test individual MCP server"""
        print(f"\n{'='*50}")
        print(f"Testing {server_name}")
        print(f"{'='*50}")
        
        # Build Docker image
        build_success = self.build_docker_image(server_name, config)
        
        if not build_success:
            self.results[server_name] = {
                'build': False,
                'stdio_test': False,
                'status': 'Build Failed'
            }
            return
        
        # Test stdio mode
        stdio_success = self.test_mcp_stdio(server_name, config)
        
        self.results[server_name] = {
            'build': build_success,
            'stdio_test': stdio_success,
            'status': 'Passed' if build_success and stdio_success else 'Failed'
        }
    
    def run_all_tests(self):
        """Run tests for all MCP servers"""
        print("🚀 Starting MCP Server Test Suite")
        print(f"Testing {len(MCP_SERVERS)} servers...")
        
        for server_name, config in MCP_SERVERS.items():
            self.test_server(server_name, config)
        
        # Print summary
        self.print_summary()
    
    def print_summary(self):
        """Print test summary"""
        print(f"\n{'='*60}")
        print("📊 Test Summary")
        print(f"{'='*60}")
        print(f"{'Server':<25} {'Build':<10} {'STDIO':<10} {'Status':<10}")
        print(f"{'-'*60}")
        
        passed = 0
        for server, result in self.results.items():
            build = '✅' if result['build'] else '❌'
            stdio = '✅' if result['stdio_test'] else '❌'
            status = result['status']
            
            print(f"{server:<25} {build:<10} {stdio:<10} {status:<10}")
            
            if status == 'Passed':
                passed += 1
        
        print(f"{'-'*60}")
        print(f"Total: {passed}/{len(self.results)} passed")
        
        # Save results
        results_file = self.base_path / 'reports' / 'test-results.json'
        with open(results_file, 'w') as f:
            json.dump(self.results, f, indent=2)
        print(f"\nResults saved to: {results_file}")

if __name__ == '__main__':
    tester = MCPServerTester()
    tester.run_all_tests()