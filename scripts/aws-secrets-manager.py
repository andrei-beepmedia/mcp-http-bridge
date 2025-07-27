import boto3
import json
import os
from typing import Optional, Union, Dict, Any
from datetime import datetime, timedelta
from functools import lru_cache
import logging

logger = logging.getLogger(__name__)

class SecureSecretsManager:
    """
    Secure AWS Secrets Manager wrapper for MCP servers
    Implements caching and secure credential handling
    """
    
    def __init__(self, region: str = "us-east-1"):
        self.client = boto3.client('secretsmanager', region_name=region)
        self._cache: Dict[str, Dict[str, Any]] = {}
        self.cache_ttl = timedelta(hours=1)
    
    def get_secret(self, secret_name: str, key: Optional[str] = None) -> Union[str, Dict[str, Any]]:
        """
        Get secret from AWS Secrets Manager with caching
        
        Args:
            secret_name: Name of the secret in AWS
            key: Optional specific key within the secret
            
        Returns:
            Secret value (string or dict)
        """
        cache_key = f"{secret_name}:{key or 'full'}"
        
        # Check cache
        if cache_key in self._cache:
            cached = self._cache[cache_key]
            if cached['expiry'] > datetime.now():
                return cached['value']
        
        try:
            response = self.client.get_secret_value(SecretId=secret_name)
            
            # Parse secret value
            if 'SecretString' in response:
                try:
                    secret_value = json.loads(response['SecretString'])
                except json.JSONDecodeError:
                    secret_value = response['SecretString']
            else:
                raise ValueError("Binary secrets not supported")
            
            # Extract specific key if requested
            value = secret_value.get(key) if key and isinstance(secret_value, dict) else secret_value
            
            # Cache the result
            self._cache[cache_key] = {
                'value': value,
                'expiry': datetime.now() + self.cache_ttl
            }
            
            return value
            
        except Exception as e:
            logger.error(f"Failed to retrieve secret {secret_name}: {str(e)}")
            raise
    
    def clear_cache(self):
        """Clear cache for security or refresh purposes"""
        self._cache.clear()


# MCP-specific secret mappings
MCP_SECRET_MAPPINGS = {
    # Personal account secrets
    'NOTION_API_KEY': 'hasna/tool/notion/hasna/api',
    'STRIPE_API_KEY': 'hasna/tool/stripe/credentials',
    'OPENAI_API_KEY': 'hasna/tool/openai/api',
    'SLACK_TOKEN': 'hasna/tool/slack/credentials',
    'GITHUB_TOKEN': 'hasna/tool/github/credentials',
    
    # Beepmedia account secrets
    'NOTION_API_KEY_BEEPMEDIA': 'beepmedia/tool/notion/general/api',
    'STRIPE_API_KEY_BEEPMEDIA': 'beepmedia/tool/stripe/credentials',
    'OPENAI_API_KEY_BEEPMEDIA': 'beepmedia/tool/openai/api',
    'SLACK_TOKEN_BEEPMEDIA': 'beepmedia/tool/slack/production/bot',
    'GITHUB_TOKEN_BEEPMEDIA': 'beepmedia/tool/github/credentials',
    'PERPLEXITY_API_KEY': 'beepmedia/tool/mcp/perplexity/credentials',
    'TWILIO_CREDENTIALS': 'beepmedia/tool/twilio/credentials',
    'SENDGRID_API_KEY': 'beepmedia/tool/sendgrid/credentials',
    'MAILGUN_CREDENTIALS': 'beepmedia/tool/mailgun/credentials',
    'DISCORD_CREDENTIALS': 'beepmedia/tool/discord/credentials'
}


@lru_cache(maxsize=128)
def get_mcp_secret(mcp_secret_name: str, use_beepmedia: bool = True) -> Union[str, Dict[str, Any]]:
    """
    Get MCP secret by name
    
    Args:
        mcp_secret_name: MCP secret identifier
        use_beepmedia: Use beepmedia account secrets
        
    Returns:
        Secret value
    """
    manager = SecureSecretsManager()
    
    # Determine which secret to use
    secret_key = mcp_secret_name
    if use_beepmedia and f"{mcp_secret_name}_BEEPMEDIA" in MCP_SECRET_MAPPINGS:
        secret_key = f"{mcp_secret_name}_BEEPMEDIA"
    
    secret_path = MCP_SECRET_MAPPINGS.get(secret_key)
    if not secret_path:
        raise ValueError(f"Unknown MCP secret: {mcp_secret_name}")
    
    # Handle different secret formats
    if 'credentials' in secret_path:
        creds = manager.get_secret(secret_path)
        if isinstance(creds, dict) and 'password' in creds:
            return creds['password']  # Return API key from password field
        return creds
    
    return manager.get_secret(secret_path)


# Environment variable injection for Docker deployments
def inject_secrets_to_env(secrets_list: list[str], use_beepmedia: bool = True):
    """
    Inject secrets into environment variables for MCP servers
    
    Args:
        secrets_list: List of secret names to inject
        use_beepmedia: Use beepmedia account secrets
    """
    for secret_name in secrets_list:
        try:
            value = get_mcp_secret(secret_name, use_beepmedia)
            if isinstance(value, dict):
                # For complex secrets, inject individual keys
                for k, v in value.items():
                    env_key = f"{secret_name}_{k.upper()}"
                    os.environ[env_key] = str(v)
            else:
                os.environ[secret_name] = str(value)
            logger.info(f"Injected secret: {secret_name}")
        except Exception as e:
            logger.error(f"Failed to inject secret {secret_name}: {str(e)}")


# Singleton instance
_secrets_manager = SecureSecretsManager()

def get_secrets_manager() -> SecureSecretsManager:
    """Get singleton SecureSecretsManager instance"""
    return _secrets_manager