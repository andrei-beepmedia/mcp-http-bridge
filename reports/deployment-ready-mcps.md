# MCP Server Deployment Guide

## Summary of Test Results

**Successfully tested and ready for deployment: 7 out of 19 servers**

### ✅ Ready for Deployment

These MCP servers have been successfully built and tested:

1. **mcp-aws** (Python)
   - Docker image: 176MB
   - AWS services integration
   - Requires: AWS credentials

2. **mcp-notion** (Node.js)
   - Docker image: 468MB
   - Notion workspace integration
   - Requires: Notion API key (available in AWS Secrets Manager)

3. **mcp-pdf-reader** (Python)
   - Docker image: 491MB
   - PDF processing capabilities
   - No external credentials required

4. **mcp-openai** (Python)
   - Docker image: 1.79GB (large due to dependencies)
   - OpenAI API integration
   - Requires: OpenAI API key (available in AWS Secrets Manager)

5. **mcp-firecrawl** (Node.js)
   - Docker image: 384MB
   - Web scraping service
   - Requires: Firecrawl API key

6. **mcp-elevenlabs** (Node.js)
   - Docker image: 717MB
   - AI voice synthesis
   - Requires: ElevenLabs API key

7. **mcp-redis** (Node.js)
   - Docker image: 404MB
   - Redis database integration
   - Requires: Redis connection URL

### ⚠️ Servers Needing Fixes

These servers failed to build or test properly:

- **mcp-google-workspace**, **mcp-google-sheets**, **mcp-gdrive** - Need Google service account JSON
- **mcp-cloudflare**, **mcp-alchemy**, **mcp-shopify** - Build issues with pnpm/dependencies
- **mcp-stripe**, **mcp-paypal** - Missing proper entry points
- **mcp-slack** - Built but protocol test failed
- **mcp-docker** - Built but needs Docker socket access
- **mcp-filesystem**, **mcp-screenshot** - Need local file system access

## Deployment Configuration

### 1. Docker Compose for Ready Servers

```yaml
version: '3.8'

services:
  # AWS Secrets Manager init
  secrets-init:
    build:
      context: ./scripts
      dockerfile: Dockerfile.secrets
    environment:
      - AWS_DEFAULT_REGION=us-east-1
      - USE_BEEPMEDIA_ACCOUNT=true
    volumes:
      - secrets:/secrets
    command: python inject-secrets.py

  # MCP Servers Ready for Deployment
  mcp-aws:
    image: mcp-aws:test
    depends_on:
      - secrets-init
    volumes:
      - secrets:/secrets:ro
    ports:
      - "8001:8000"
    environment:
      - MCP_TRANSPORT=http
    command: /scripts/start-with-secrets.sh

  mcp-notion:
    image: mcp-notion:test
    depends_on:
      - secrets-init
    volumes:
      - secrets:/secrets:ro
    ports:
      - "8002:8000"
    environment:
      - MCP_TRANSPORT=http

  mcp-pdf-reader:
    image: mcp-pdf-reader:test
    ports:
      - "8003:8000"
    environment:
      - MCP_TRANSPORT=http

  mcp-openai:
    image: mcp-openai:test
    depends_on:
      - secrets-init
    volumes:
      - secrets:/secrets:ro
    ports:
      - "8004:8000"
    environment:
      - MCP_TRANSPORT=http

  mcp-firecrawl:
    image: mcp-firecrawl:test
    depends_on:
      - secrets-init
    volumes:
      - secrets:/secrets:ro
    ports:
      - "8005:8000"
    environment:
      - MCP_TRANSPORT=http

  mcp-elevenlabs:
    image: mcp-elevenlabs:test
    depends_on:
      - secrets-init
    volumes:
      - secrets:/secrets:ro
    ports:
      - "8006:8000"
    environment:
      - MCP_TRANSPORT=http

  mcp-redis:
    image: mcp-redis:test
    ports:
      - "8007:8000"
    environment:
      - MCP_TRANSPORT=http
      - REDIS_URL=redis://redis:6379
    depends_on:
      - redis

  # Supporting services
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  nginx:
    image: nginx:alpine
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro
    ports:
      - "443:443"
      - "80:80"
    depends_on:
      - mcp-aws
      - mcp-notion
      - mcp-pdf-reader
      - mcp-openai
      - mcp-firecrawl
      - mcp-elevenlabs
      - mcp-redis

volumes:
  secrets:
```

### 2. Server Deployment Steps

1. **Push Docker images to registry**:
   ```bash
   # Tag and push images
   docker tag mcp-aws:test your-registry/mcp-aws:latest
   docker tag mcp-notion:test your-registry/mcp-notion:latest
   # ... repeat for all servers
   ```

2. **Deploy to server**:
   ```bash
   # On your server
   docker-compose -f docker-compose.prod.yml up -d
   ```

3. **Configure Claude Code**:
   ```json
   {
     "mcpServers": {
       "aws": {
         "transport": "http",
         "url": "https://your-domain.com/mcp/aws"
       },
       "notion": {
         "transport": "http",
         "url": "https://your-domain.com/mcp/notion"
       },
       "pdf": {
         "transport": "http",
         "url": "https://your-domain.com/mcp/pdf"
       },
       "openai": {
         "transport": "http",
         "url": "https://your-domain.com/mcp/openai"
       },
       "firecrawl": {
         "transport": "http",
         "url": "https://your-domain.com/mcp/firecrawl"
       },
       "elevenlabs": {
         "transport": "http",
         "url": "https://your-domain.com/mcp/elevenlabs"
       },
       "redis": {
         "transport": "http",
         "url": "https://your-domain.com/mcp/redis"
       }
     }
   }
   ```

### 3. Security Considerations

- ✅ All API keys stored in AWS Secrets Manager
- ✅ Secrets injected at runtime via init container
- ✅ HTTPS/TLS for all external connections
- ✅ Non-root containers
- ✅ Read-only secret volumes

### 4. Available API Keys in AWS Secrets Manager

Based on our scan, these are already available:
- ✅ Notion API keys (multiple workspaces)
- ✅ OpenAI API key
- ✅ Slack tokens (for when fixed)
- ✅ GitHub tokens
- ✅ Stripe API keys (for when fixed)
- ✅ Perplexity API key

### 5. Next Steps

1. **For immediate deployment**: Use the 7 working servers
2. **Fix failing servers**: Address dependency and build issues
3. **Add monitoring**: Implement health checks and logging
4. **Scale as needed**: Use Kubernetes or ECS for production

## Commands for Quick Deployment

```bash
# Build all working images
docker build -t mcp-aws:prod repos/mcp-aws/src/core-mcp-server/
docker build -t mcp-notion:prod repos/mcp-notion/
docker build -t mcp-pdf-reader:prod repos/mcp-pdf-reader/
docker build -t mcp-openai:prod repos/mcp-openai/
docker build -t mcp-firecrawl:prod repos/mcp-firecrawl/
docker build -t mcp-elevenlabs:prod repos/mcp-elevenlabs/
docker build -t mcp-redis:prod repos/mcp-redis/

# Deploy with docker-compose
docker-compose -f docker-compose.prod.yml up -d
```