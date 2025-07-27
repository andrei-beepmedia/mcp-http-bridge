#!/usr/bin/env python3
"""
Update Cloudflare DNS record for mcp.beepmedia.com to production IP
"""
import os
import json
import boto3
import requests
from typing import Dict, Optional

# AWS Configuration using Beepmedia credentials
AWS_ACCESS_KEY_ID = os.environ.get('BEEPMEDIA_AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY = os.environ.get('BEEPMEDIA_AWS_SECRET_ACCESS_KEY')
AWS_REGION = 'us-east-1'

# DNS Record to update
DNS_RECORD = {
    'name': 'mcp.beepmedia.com',
    'type': 'A',
    'content': '44.206.106.173',  # Production Elastic IP
    'proxied': False
}

class CloudflareManager:
    """Manage Cloudflare DNS records"""
    
    def __init__(self, api_token: str, api_email: Optional[str] = None):
        self.api_token = api_token
        self.api_email = api_email
        
        # Set headers based on authentication method
        if api_email:
            # Using API Key + Email (old method)
            self.headers = {
                'X-Auth-Key': api_token,
                'X-Auth-Email': api_email,
                'Content-Type': 'application/json'
            }
        else:
            # Using API Token (new method)
            self.headers = {
                'Authorization': f'Bearer {api_token}',
                'Content-Type': 'application/json'
            }
        
        self.base_url = 'https://api.cloudflare.com/client/v4'
    
    def get_zone_id(self, domain: str) -> Optional[str]:
        """Get zone ID for a domain"""
        # Extract base domain (beepmedia.com from *.beepmedia.com)
        parts = domain.split('.')
        base_domain = '.'.join(parts[-2:])
        
        response = requests.get(
            f'{self.base_url}/zones',
            headers=self.headers,
            params={'name': base_domain}
        )
        
        if response.status_code == 200:
            data = response.json()
            if data['success'] and data['result']:
                return data['result'][0]['id']
        
        print(f"Error getting zone ID: {response.status_code} - {response.text}")
        return None
    
    def get_existing_record(self, zone_id: str, name: str) -> Optional[Dict]:
        """Check if a DNS record already exists"""
        response = requests.get(
            f'{self.base_url}/zones/{zone_id}/dns_records',
            headers=self.headers,
            params={'name': name}
        )
        
        if response.status_code == 200:
            data = response.json()
            if data['success'] and data['result']:
                return data['result'][0]
        
        return None
    
    def update_record(self, zone_id: str, record: Dict) -> bool:
        """Update a DNS record"""
        existing = self.get_existing_record(zone_id, record['name'])
        
        if existing:
            print(f"Current record: {record['name']} -> {existing['content']}")
            print(f"Updating to: {record['name']} -> {record['content']}")
            
            response = requests.put(
                f"{self.base_url}/zones/{zone_id}/dns_records/{existing['id']}",
                headers=self.headers,
                json=record
            )
            
            if response.status_code == 200:
                data = response.json()
                if data['success']:
                    print(f"Successfully updated: {record['name']} -> {record['content']}")
                    return True
            
            print(f"Error updating record: {response.status_code} - {response.text}")
            return False
        else:
            print(f"No existing record found for: {record['name']}")
            return False

def get_cloudflare_credentials():
    """Retrieve Cloudflare API credentials from AWS Secrets Manager"""
    print("Connecting to AWS Secrets Manager...")
    
    # Create AWS client with Beepmedia credentials
    client = boto3.client(
        'secretsmanager',
        region_name=AWS_REGION,
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY
    )
    
    # Try known Cloudflare secret names first
    possible_names = [
        'beepmedia/tool/cloudflare/api',
        'beepmedia/tool/cloudflare/credentials',
        'cloudflare-api-token',
        'cloudflare-api-key',
        'cloudflare/api-token',
        'cloudflare/api-key',
        'beepmedia/cloudflare',
        'beepmedia/cloudflare/api',
        'beepmedia/prod/cloudflare',
        'beepmedia/api/cloudflare',
        'prod/cloudflare',
        'cf-api-token',
        'cf-api-key',
        'beepmedia/cf'
    ]
    
    for name in possible_names:
        try:
            print(f"Trying secret: {name}")
            secret_value = client.get_secret_value(SecretId=name)
            
            # Try to parse as JSON
            try:
                return json.loads(secret_value['SecretString'])
            except json.JSONDecodeError:
                # If not JSON, assume it's the API token directly
                return {'api_token': secret_value['SecretString']}
        except client.exceptions.ResourceNotFoundException:
            continue
        except Exception as e:
            print(f"Error retrieving {name}: {str(e)}")
    
    # If not found by known names, search through all secrets
    print("\nSearching through all secrets for Cloudflare credentials...")
    try:
        response = client.list_secrets(MaxResults=100)
        all_secrets = response['SecretList']
        
        # Handle pagination
        while 'NextToken' in response:
            response = client.list_secrets(MaxResults=100, NextToken=response['NextToken'])
            all_secrets.extend(response['SecretList'])
        
        # Look for Cloudflare-related secrets
        for secret in all_secrets:
            name_lower = secret['Name'].lower()
            if 'cloudflare' in name_lower or 'cf' in name_lower:
                print(f"Found potential Cloudflare secret: {secret['Name']}")
                
                try:
                    secret_value = client.get_secret_value(SecretId=secret['Name'])
                    
                    # Try to parse as JSON
                    try:
                        creds = json.loads(secret_value['SecretString'])
                        # Check if it contains API credentials
                        if any(key in creds for key in ['api_token', 'api_key', 'token']):
                            return creds
                    except json.JSONDecodeError:
                        # If not JSON and not a PEM file, assume it's the API token
                        if not secret_value['SecretString'].startswith('-----'):
                            return {'api_token': secret_value['SecretString']}
                except Exception as e:
                    print(f"Error retrieving {secret['Name']}: {str(e)}")
        
    except Exception as e:
        print(f"Error listing secrets: {str(e)}")
    
    return None

def main():
    """Main function to update DNS record"""
    print("Updating Cloudflare DNS for mcp.beepmedia.com")
    print("=" * 50)
    
    # Check AWS credentials
    if not AWS_ACCESS_KEY_ID or not AWS_SECRET_ACCESS_KEY:
        print("Error: BEEPMEDIA AWS credentials not found in environment")
        print("Please ensure BEEPMEDIA_AWS_ACCESS_KEY_ID and BEEPMEDIA_AWS_SECRET_ACCESS_KEY are set")
        return
    
    # Get Cloudflare credentials from AWS
    cloudflare_creds = get_cloudflare_credentials()
    
    if not cloudflare_creds:
        print("\nError: Could not retrieve Cloudflare credentials from AWS Secrets Manager")
        print("\nPlease ensure Cloudflare API credentials are stored in AWS Secrets Manager")
        return
    
    # Extract API token or key
    api_token = cloudflare_creds.get('api_token') or cloudflare_creds.get('api_key') or cloudflare_creds.get('token')
    api_email = cloudflare_creds.get('email') or cloudflare_creds.get('api_email')
    
    if not api_token:
        print("Error: No API token/key found in Cloudflare credentials")
        print(f"Available keys: {list(cloudflare_creds.keys())}")
        return
    
    print("\nCloudflare API credentials retrieved successfully")
    
    # Initialize Cloudflare manager
    cf = CloudflareManager(api_token, api_email)
    
    # Get zone ID
    zone_id = cf.get_zone_id('beepmedia.com')
    
    if not zone_id:
        print("Error: Could not find Cloudflare zone for beepmedia.com")
        return
    
    print(f"\nFound Cloudflare zone ID: {zone_id}")
    
    # Update DNS record
    print(f"\nUpdating DNS record:")
    if cf.update_record(zone_id, DNS_RECORD):
        print("\nDNS update completed successfully!")
        print(f"\nmcp.beepmedia.com now points to {DNS_RECORD['content']} (Production Elastic IP)")
    else:
        print("\nFailed to update DNS record. Please check the errors above.")

if __name__ == '__main__':
    main()