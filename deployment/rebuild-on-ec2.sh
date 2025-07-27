#!/bin/bash
# Rebuild MCP Docker images on EC2 for AMD64 compatibility

set -e

echo "🔨 Rebuilding MCP Docker images on EC2"
echo "======================================"

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose down

# Clone repositories
echo "📦 Cloning MCP repositories..."
mkdir -p /opt/mcp-servers/repos
cd /opt/mcp-servers/repos

# Clone each repository
repos=(
    "https://github.com/makenotion/notion-mcp-server.git mcp-notion"
    "https://github.com/Safe-Swiss-Cloud-AG/mcp_pdf_reader.git mcp-pdf-reader"
    "https://github.com/daodao97/openai-mcp.git mcp-openai"
    "https://github.com/mendableai/firecrawl-mcp-server.git mcp-firecrawl"
    "https://github.com/elevenlabs/elevenlabs-mcp.git mcp-elevenlabs"
    "https://github.com/redis/mcp-redis.git mcp-redis"
)

for repo in "${repos[@]}"; do
    url=$(echo $repo | cut -d' ' -f1)
    name=$(echo $repo | cut -d' ' -f2)
    if [ ! -d "$name" ]; then
        echo "Cloning $name..."
        git clone $url $name || echo "Failed to clone $name"
    fi
done

# AWS MCP (special case)
if [ ! -d "mcp-aws" ]; then
    git clone https://github.com/awslabs/mcp.git mcp-aws
fi

# Build images
echo "🐳 Building Docker images..."
cd /opt/mcp-servers

# Build AWS MCP
echo "Building mcp-aws..."
cd repos/mcp-aws/src/core-mcp-server
docker build -t mcp-aws:latest . || echo "Failed to build mcp-aws"
cd /opt/mcp-servers

# Build Notion MCP
echo "Building mcp-notion..."
cd repos/mcp-notion
docker build -t mcp-notion:latest . || echo "Failed to build mcp-notion"
cd /opt/mcp-servers

# Build PDF Reader MCP
echo "Building mcp-pdf-reader..."
cd repos/mcp-pdf-reader
# Create Dockerfile if missing
if [ ! -f Dockerfile ]; then
    cat > Dockerfile << 'EOF'
FROM python:3.11-slim
RUN apt-get update && apt-get install -y poppler-utils && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/bash mcp
WORKDIR /app
COPY . .
RUN pip install --no-cache-dir PyPDF2 pdfplumber pymupdf mcp
USER mcp
ENV PYTHONUNBUFFERED=1
CMD ["python", "mcp_pdf_reader.py"]
EOF
fi
docker build -t mcp-pdf-reader:latest . || echo "Failed to build mcp-pdf-reader"
cd /opt/mcp-servers

# Build OpenAI MCP
echo "Building mcp-openai..."
cd repos/mcp-openai
if [ ! -f Dockerfile ]; then
    cat > Dockerfile << 'EOF'
FROM python:3.11-slim
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "mcp_server.py"]
EOF
fi
docker build -t mcp-openai:latest . || echo "Failed to build mcp-openai"
cd /opt/mcp-servers

# Build Firecrawl MCP
echo "Building mcp-firecrawl..."
cd repos/mcp-firecrawl
docker build -t mcp-firecrawl:latest . || echo "Failed to build mcp-firecrawl"
cd /opt/mcp-servers

# Build ElevenLabs MCP
echo "Building mcp-elevenlabs..."
cd repos/mcp-elevenlabs
docker build -t mcp-elevenlabs:latest . || echo "Failed to build mcp-elevenlabs"
cd /opt/mcp-servers

# Build Redis MCP
echo "Building mcp-redis..."
cd repos/mcp-redis
docker build -t mcp-redis:latest . || echo "Failed to build mcp-redis"
cd /opt/mcp-servers

# Start services
echo "🚀 Starting services..."
docker-compose up -d

# Check status
echo "📊 Checking container status..."
sleep 5
docker ps

echo "✅ Rebuild complete!"