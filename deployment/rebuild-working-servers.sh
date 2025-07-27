#!/bin/bash
# Rebuild only the working MCP servers

set -e

echo "🔨 Rebuilding working MCP servers"
echo "================================"

cd /opt/mcp-servers

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Build working images directly from transferred tar files
echo "🐳 Loading and tagging images..."

# These images should already be loaded, just tag them
docker tag mcp-aws:test mcp-aws:latest 2>/dev/null || echo "AWS image not found"
docker tag mcp-notion:test mcp-notion:latest 2>/dev/null || echo "Notion image not found"
docker tag mcp-pdf-reader:test mcp-pdf-reader:latest 2>/dev/null || echo "PDF reader image not found"
docker tag mcp-openai:test mcp-openai:latest 2>/dev/null || echo "OpenAI image not found"
docker tag mcp-firecrawl:test mcp-firecrawl:latest 2>/dev/null || echo "Firecrawl image not found"
docker tag mcp-elevenlabs:test mcp-elevenlabs:latest 2>/dev/null || echo "ElevenLabs image not found"
docker tag mcp-redis:test mcp-redis:latest 2>/dev/null || echo "Redis image not found"

# Create simplified docker-compose
cat > docker-compose-simple.yml << 'EOF'
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    container_name: mcp-redis-cache
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data

  pdf-reader:
    image: mcp-pdf-reader:latest
    container_name: mcp-pdf-reader
    restart: unless-stopped
    ports:
      - "8003:8000"
    environment:
      - MCP_TRANSPORT=stdio

volumes:
  redis-data:
EOF

# Test with simple services first
echo "🚀 Starting services..."
docker-compose -f docker-compose-simple.yml up -d

# Check status
echo "📊 Checking container status..."
sleep 5
docker ps

# Test PDF reader endpoint
echo "🧪 Testing PDF reader..."
curl -s http://localhost:8003/health || echo "PDF reader not responding to HTTP"

echo "✅ Basic services started!"
echo ""
echo "To test MCP protocol:"
echo 'echo {"jsonrpc":"2.0","method":"tools/list","id":1} | docker exec -i mcp-pdf-reader python mcp_pdf_reader.py'