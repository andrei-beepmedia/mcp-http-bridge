#!/bin/bash
# Setup script for EC2 instance with Docker and Nginx

set -e

echo "🚀 Starting EC2 MCP Server Setup"
echo "================================"

# Update system
echo "📦 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker
echo "🐳 Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu
sudo systemctl enable docker
sudo systemctl start docker

# Install Docker Compose
echo "🐳 Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Nginx
echo "🌐 Installing Nginx..."
sudo apt-get install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# Install other dependencies
echo "📦 Installing additional tools..."
sudo apt-get install -y git curl wget unzip jq python3-pip

# Install AWS CLI
echo "☁️ Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws/

# Create directories
echo "📁 Creating directory structure..."
sudo mkdir -p /opt/mcp-servers/{configs,certs,scripts,data}
sudo mkdir -p /var/log/mcp-servers
sudo chown -R ubuntu:ubuntu /opt/mcp-servers
sudo chown -R ubuntu:ubuntu /var/log/mcp-servers

# Configure firewall
echo "🔥 Configuring firewall..."
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8000:8020/tcp
sudo ufw --force enable

# Create MCP user
echo "👤 Creating MCP service user..."
sudo useradd -r -s /bin/false -d /opt/mcp-servers mcp-service || true

echo "✅ Basic setup complete!"
echo ""
echo "Next steps:"
echo "1. Log out and back in for Docker group to take effect"
echo "2. Configure AWS CLI with credentials"
echo "3. Deploy MCP servers"
echo ""