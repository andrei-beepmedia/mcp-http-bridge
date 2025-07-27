#!/usr/bin/env python3

import boto3
import os
import sys
from botocore.exceptions import ClientError, NoCredentialsError

# Set AWS credentials from environment variables
aws_access_key_id = os.environ.get('BEEPMEDIA_AWS_ACCESS_KEY_ID')
aws_secret_access_key = os.environ.get('BEEPMEDIA_AWS_SECRET_ACCESS_KEY')

if not aws_access_key_id or not aws_secret_access_key:
    print("Error: BEEPMEDIA AWS credentials not found in environment variables")
    sys.exit(1)

# Create EC2 client with beepmedia credentials
ec2 = boto3.client(
    'ec2',
    aws_access_key_id=aws_access_key_id,
    aws_secret_access_key=aws_secret_access_key,
    region_name='us-east-1'  # Change this if your resources are in a different region
)

def get_security_group(sg_name):
    """Get security group by name"""
    try:
        response = ec2.describe_security_groups(
            Filters=[
                {
                    'Name': 'group-name',
                    'Values': [sg_name]
                }
            ]
        )
        
        if response['SecurityGroups']:
            return response['SecurityGroups'][0]
        else:
            print(f"Security group '{sg_name}' not found")
            return None
            
    except ClientError as e:
        print(f"Error retrieving security group: {e}")
        return None

def remove_port_range(sg_id, port_range_start, port_range_end):
    """Remove a port range from security group"""
    try:
        # Remove the ingress rule for the port range
        ec2.revoke_security_group_ingress(
            GroupId=sg_id,
            IpPermissions=[
                {
                    'IpProtocol': 'tcp',
                    'FromPort': port_range_start,
                    'ToPort': port_range_end,
                    'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
                }
            ]
        )
        print(f"Successfully removed port range {port_range_start}-{port_range_end} from security group")
        return True
        
    except ClientError as e:
        if 'InvalidPermission.NotFound' in str(e):
            print(f"Port range {port_range_start}-{port_range_end} not found in security group rules")
        else:
            print(f"Error removing port range: {e}")
        return False

def display_security_group_rules(sg):
    """Display current security group rules"""
    print(f"\nSecurity Group: {sg['GroupName']} ({sg['GroupId']})")
    print(f"Description: {sg['Description']}")
    print("\nInbound Rules:")
    print("-" * 80)
    print(f"{'Protocol':<10} {'Port Range':<15} {'Source':<20} {'Description'}")
    print("-" * 80)
    
    for rule in sg['IpPermissions']:
        protocol = rule['IpProtocol']
        if protocol == '-1':
            protocol = 'All'
            
        from_port = rule.get('FromPort', 'All')
        to_port = rule.get('ToPort', 'All')
        
        if from_port == to_port:
            port_range = str(from_port)
        else:
            port_range = f"{from_port}-{to_port}"
            
        # Handle different source types
        sources = []
        if rule.get('IpRanges'):
            sources.extend([r['CidrIp'] for r in rule['IpRanges']])
        if rule.get('Ipv6Ranges'):
            sources.extend([r['CidrIpv6'] for r in rule['Ipv6Ranges']])
        if rule.get('UserIdGroupPairs'):
            sources.extend([f"sg-{g['GroupId']}" for g in rule['UserIdGroupPairs']])
            
        source = ', '.join(sources) if sources else 'N/A'
        
        # Get description if available
        description = ''
        if rule.get('IpRanges') and rule['IpRanges'] and rule['IpRanges'][0].get('Description'):
            description = rule['IpRanges'][0]['Description']
            
        print(f"{protocol:<10} {port_range:<15} {source:<20} {description}")

def main():
    sg_name = 'beepmedia-mcp-sg'
    
    print(f"Connecting to AWS with beepmedia credentials...")
    print(f"Looking for security group: {sg_name}")
    
    # Get the security group
    sg = get_security_group(sg_name)
    if not sg:
        # Try different regions if not found in us-east-1
        regions = ['us-west-2', 'eu-west-1', 'ap-southeast-1']
        for region in regions:
            print(f"\nTrying region: {region}")
            ec2_regional = boto3.client(
                'ec2',
                aws_access_key_id=aws_access_key_id,
                aws_secret_access_key=aws_secret_access_key,
                region_name=region
            )
            
            try:
                response = ec2_regional.describe_security_groups(
                    Filters=[
                        {
                            'Name': 'group-name',
                            'Values': [sg_name]
                        }
                    ]
                )
                
                if response['SecurityGroups']:
                    sg = response['SecurityGroups'][0]
                    global ec2
                    ec2 = ec2_regional
                    print(f"Found security group in region: {region}")
                    break
                    
            except ClientError:
                continue
                
        if not sg:
            print("\nCould not find the security group in any common region.")
            print("\nListing all security groups in us-east-1:")
            try:
                all_sgs = ec2.describe_security_groups()
                for security_group in all_sgs['SecurityGroups']:
                    print(f"  - {security_group['GroupName']} ({security_group['GroupId']})")
            except ClientError as e:
                print(f"Error listing security groups: {e}")
            return
    
    sg_id = sg['GroupId']
    
    print("\nCurrent security group rules:")
    display_security_group_rules(sg)
    
    # Remove port range 8000-8020
    print(f"\nRemoving port range 8000-8020 from security group {sg_name}...")
    remove_port_range(sg_id, 8000, 8020)
    
    # Get updated security group
    sg = get_security_group(sg_name)
    if sg:
        print("\nUpdated security group rules:")
        display_security_group_rules(sg)
        
        # Verify required ports are still open
        print("\nVerifying required ports:")
        required_ports = {'22': 'SSH', '80': 'HTTP', '443': 'HTTPS'}
        for rule in sg['IpPermissions']:
            from_port = str(rule.get('FromPort', ''))
            if from_port in required_ports:
                print(f"✓ Port {from_port} ({required_ports[from_port]}) is open")
                del required_ports[from_port]
                
        if required_ports:
            print("\n⚠️  Warning: The following required ports are not open:")
            for port, service in required_ports.items():
                print(f"  - Port {port} ({service})")

if __name__ == "__main__":
    main()