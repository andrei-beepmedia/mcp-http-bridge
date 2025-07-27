#!/bin/bash
# Deploy MCP servers to EC2 instance

set -e

echo "🚀 Deploying MCP Servers"
echo "======================="

# Create deployment directory on server
echo "📁 Creating directories..."
ssh -i beepmedia-dev-mcp-key.pem ubuntu@3.215.253.37 << 'EOF'
mkdir -p /opt/mcp-servers/{images,configs,scripts}
cd /opt/mcp-servers
EOF

# Copy docker-compose and nginx config
echo "📋 Copying configuration files..."
scp -i beepmedia-dev-mcp-key.pem docker-compose.yml ubuntu@3.215.253.37:/opt/mcp-servers/
scp -i beepmedia-dev-mcp-key.pem nginx.conf ubuntu@3.215.253.37:/opt/mcp-servers/configs/

# Copy and load Docker images
echo "🐳 Transferring Docker images..."
for image in mcp-aws mcp-notion mcp-pdf-reader mcp-openai mcp-firecrawl mcp-elevenlabs mcp-redis; do
    if docker images | grep -q "$image.*test"; then
        echo "   Saving $image..."
        docker save "$image:test" | gzip > "$image.tar.gz"
        echo "   Uploading $image..."
        scp -i beepmedia-dev-mcp-key.pem "$image.tar.gz" ubuntu@3.215.253.37:/opt/mcp-servers/images/
        rm "$image.tar.gz"
    fi
done

# Load images and start services on server
echo "🔧 Setting up services on server..."
ssh -i beepmedia-dev-mcp-key.pem ubuntu@3.215.253.37 << 'EOF'
cd /opt/mcp-servers

# Load Docker images
echo "Loading Docker images..."
for image in images/*.tar.gz; do
    if [ -f "$image" ]; then
        echo "   Loading $(basename $image)..."
        gunzip -c "$image" | docker load
    fi
done

# Tag images as latest
docker tag mcp-aws:test mcp-aws:latest
docker tag mcp-notion:test mcp-notion:latest
docker tag mcp-pdf-reader:test mcp-pdf-reader:latest
docker tag mcp-openai:test mcp-openai:latest
docker tag mcp-firecrawl:test mcp-firecrawl:latest
docker tag mcp-elevenlabs:test mcp-elevenlabs:latest
docker tag mcp-redis:test mcp-redis:latest

# Create .env file (will be populated with real credentials later)
cat > .env << 'ENVEOF'
# AWS Credentials
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret

# API Keys
NOTION_API_KEY=your_notion_key
OPENAI_API_KEY=your_openai_key
FIRECRAWL_API_KEY=your_firecrawl_key
ELEVENLABS_API_KEY=your_elevenlabs_key
ENVEOF

# Copy Nginx configuration
sudo cp configs/nginx.conf /etc/nginx/sites-available/mcp-servers
sudo ln -sf /etc/nginx/sites-available/mcp-servers /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx

echo "✅ Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Update /opt/mcp-servers/.env with real API keys"
echo "2. Run: docker-compose up -d"
echo "3. Set up SSL with Let's Encrypt"
echo "4. Configure Cloudflare DNS"
EOF

echo "✅ Deployment script complete!"