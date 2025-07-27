#!/usr/bin/env python3

import boto3
import os
from datetime import datetime

# Set up AWS credentials from environment
aws_access_key_id = os.environ.get('BEEPMEDIA_AWS_ACCESS_KEY_ID')
aws_secret_access_key = os.environ.get('BEEPMEDIA_AWS_SECRET_ACCESS_KEY')

if not aws_access_key_id or not aws_secret_access_key:
    print("Error: AWS credentials not found in environment variables")
    print("Please set BEEPMEDIA_AWS_ACCESS_KEY_ID and BEEPMEDIA_AWS_SECRET_ACCESS_KEY")
    exit(1)

# Create EC2 client
ec2_client = boto3.client(
    'ec2',
    aws_access_key_id=aws_access_key_id,
    aws_secret_access_key=aws_secret_access_key,
    region_name='us-east-1'  # Default region, will try multiple regions
)

# Get all regions
regions = [region['RegionName'] for region in ec2_client.describe_regions()['Regions']]

print(f"Checking Elastic IPs across {len(regions)} regions...")
print("-" * 80)

total_allocated = 0
total_associated = 0
total_unassociated = 0

for region in regions:
    # Create regional client
    regional_client = boto3.client(
        'ec2',
        aws_access_key_id=aws_access_key_id,
        aws_secret_access_key=aws_secret_access_key,
        region_name=region
    )
    
    try:
        # Get Elastic IPs for this region
        response = regional_client.describe_addresses()
        addresses = response['Addresses']
        
        if addresses:
            print(f"\nRegion: {region}")
            print(f"  Elastic IPs: {len(addresses)}")
            
            associated = [addr for addr in addresses if 'InstanceId' in addr or 'NetworkInterfaceId' in addr]
            unassociated = [addr for addr in addresses if 'InstanceId' not in addr and 'NetworkInterfaceId' not in addr]
            
            print(f"  - Associated: {len(associated)}")
            print(f"  - Unassociated: {len(unassociated)}")
            
            total_allocated += len(addresses)
            total_associated += len(associated)
            total_unassociated += len(unassociated)
            
            if unassociated:
                print(f"  Unassociated IPs:")
                for addr in unassociated:
                    print(f"    - {addr['PublicIp']} (Allocation ID: {addr['AllocationId']})")
                    if 'Tags' in addr:
                        for tag in addr['Tags']:
                            if tag['Key'] == 'Name':
                                print(f"      Name: {tag['Value']}")
            
            if associated:
                print(f"  Associated IPs:")
                for addr in associated:
                    instance_id = addr.get('InstanceId', 'N/A')
                    network_interface = addr.get('NetworkInterfaceId', 'N/A')
                    print(f"    - {addr['PublicIp']} -> Instance: {instance_id}, Interface: {network_interface}")
                    if 'Tags' in addr:
                        for tag in addr['Tags']:
                            if tag['Key'] == 'Name':
                                print(f"      Name: {tag['Value']}")
    
    except Exception as e:
        # Skip regions with errors (likely permission issues)
        pass

print("\n" + "=" * 80)
print(f"SUMMARY:")
print(f"Total Elastic IPs allocated: {total_allocated}")
print(f"Total Associated: {total_associated}")
print(f"Total Unassociated (costing money): {total_unassociated}")

if total_unassociated > 0:
    # Approximate cost (as of 2024, AWS charges ~$0.005/hour for unassociated EIPs)
    hourly_cost = total_unassociated * 0.005
    monthly_cost = hourly_cost * 24 * 30
    print(f"\nEstimated cost for unassociated IPs:")
    print(f"  Per hour: ${hourly_cost:.3f}")
    print(f"  Per month: ${monthly_cost:.2f}")
    print("\nConsider releasing unassociated Elastic IPs to avoid charges!")