#!/usr/bin/env python3
"""
Inject secrets from AWS Secrets Manager into files for Docker containers
This runs as an init container to prepare secrets before MCP servers start
"""

import os
import json
import sys
from aws_secrets_manager import get_mcp_secret, MCP_SECRET_MAPPINGS

# Define which secrets each MCP server needs
MCP_SERVER_SECRETS = {
    'notion': ['NOTION_API_KEY'],
    'slack': ['SLACK_TOKEN'],
    'stripe': ['STRIPE_API_KEY'],
    'openai': ['OPENAI_API_KEY'],
    'gdrive': ['GOOGLE_SERVICE_ACCOUNT'],
    'cloudflare': ['CLOUDFLARE_API_TOKEN'],
    'paypal': ['PAYPAL_ACCESS_TOKEN'],
    'shopify': ['SHOPIFY_API_KEY'],
    'firecrawl': ['FIRECRAWL_API_KEY'],
    'elevenlabs': ['ELEVENLABS_API_KEY'],
    'alchemy': ['ALCHEMY_API_KEY'],
    'sendgrid': ['SENDGRID_API_KEY'],
    'twilio': ['TWILIO_CREDENTIALS'],
    'perplexity': ['PERPLEXITY_API_KEY']
}

def inject_secrets():
    """Fetch secrets from AWS and write to shared volume"""
    use_beepmedia = os.getenv('USE_BEEPMEDIA_ACCOUNT', 'true').lower() == 'true'
    secrets_dir = '/secrets'
    
    # Create secrets directory
    os.makedirs(secrets_dir, exist_ok=True)
    
    # Collect all unique secrets needed
    all_secrets = set()
    for server_secrets in MCP_SERVER_SECRETS.values():
        all_secrets.update(server_secrets)
    
    # Fetch and store secrets
    secrets_data = {}
    for secret_name in all_secrets:
        try:
            print(f"Fetching secret: {secret_name}")
            value = get_mcp_secret(secret_name, use_beepmedia)
            
            # Handle different secret types
            if isinstance(value, dict):
                secrets_data[secret_name] = value
            else:
                secrets_data[secret_name] = str(value)
                
            print(f"✓ Retrieved {secret_name}")
            
        except Exception as e:
            print(f"✗ Failed to retrieve {secret_name}: {str(e)}", file=sys.stderr)
            # Continue with other secrets
    
    # Write secrets to files for each server
    for server, required_secrets in MCP_SERVER_SECRETS.items():
        server_secrets = {}
        for secret in required_secrets:
            if secret in secrets_data:
                server_secrets[secret] = secrets_data[secret]
        
        # Write server-specific secrets file
        secrets_file = os.path.join(secrets_dir, f'{server}.json')
        with open(secrets_file, 'w') as f:
            json.dump(server_secrets, f)
        os.chmod(secrets_file, 0o600)  # Restrict access
        print(f"Created secrets file for {server}")
    
    # Also write a combined secrets file
    combined_file = os.path.join(secrets_dir, 'all-secrets.json')
    with open(combined_file, 'w') as f:
        json.dump(secrets_data, f)
    os.chmod(combined_file, 0o600)
    
    print("Secret injection completed successfully")

if __name__ == '__main__':
    inject_secrets()