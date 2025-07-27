# MCP Server Dockerfiles

This directory contains Dockerfiles for various MCP (Model Context Protocol) servers. These Dockerfiles follow security best practices and are optimized for production use.

## Available Dockerfiles

### Python-based Servers

1. **mcp-google-sheets.Dockerfile** - Google Sheets MCP Server
   - Base: Python 3.11 slim
   - Features: OAuth integration, spreadsheet manipulation
   - Security: Non-root user, minimal image

2. **mcp-aws-improved.Dockerfile** - AWS MCP Server (Improved)
   - Base: Python 3.13 slim with hash verification
   - Features: AWS SDK integration, multiple AWS services
   - Security: Non-root user, capability dropping, hash-verified dependencies

3. **mcp-google-workspace-improved.Dockerfile** - Google Workspace MCP Server (Improved)
   - Base: Python 3.11 Alpine (smaller image)
   - Features: Gmail, Calendar, Docs, Sheets, Slides, Drive integration
   - Security: Non-root user, Alpine-based for minimal attack surface

### Node.js-based Servers

1. **mcp-gdrive.Dockerfile** - Google Drive MCP Server
   - Base: Node.js 20 LTS slim
   - Features: Google Drive and Sheets integration
   - Security: Non-root user, dumb-init for signal handling

2. **mcp-notion-improved.Dockerfile** - Notion MCP Server (Improved)
   - Base: Node.js 20 with distroless runtime
   - Features: Notion API integration
   - Security: Distroless image for minimal attack surface

## Building Images

To build any of these images:

```bash
# Build from the repos directory
cd /Users/andreihasna/Missions/beepmedia/mission-mcps/repos

# For Google Sheets
docker build -f ../dockerfiles/mcp-google-sheets.Dockerfile -t mcp-google-sheets:latest ./mcp-google-sheets

# For Google Drive
docker build -f ../dockerfiles/mcp-gdrive.Dockerfile -t mcp-gdrive:latest ./mcp-gdrive

# For AWS (improved)
docker build -f ../dockerfiles/mcp-aws-improved.Dockerfile -t mcp-aws:latest ./mcp-aws/src/aws-api-mcp-server

# For Notion (improved)
docker build -f ../dockerfiles/mcp-notion-improved.Dockerfile -t mcp-notion:latest ./mcp-notion

# For Google Workspace (improved)
docker build -f ../dockerfiles/mcp-google-workspace-improved.Dockerfile -t mcp-google-workspace:latest ./mcp-google-workspace
```

## Running Containers

### Google Sheets
```bash
docker run -it --rm \
  -v ~/.config/gcloud:/home/mcp/.config/gcloud:ro \
  -e GOOGLE_APPLICATION_CREDENTIALS=/home/mcp/.config/gcloud/application_default_credentials.json \
  mcp-google-sheets:latest
```

### Google Drive
```bash
docker run -it --rm \
  -v ~/.config/gcloud:/home/mcp/.config/gcloud:ro \
  -e GOOGLE_APPLICATION_CREDENTIALS=/home/mcp/.config/gcloud/application_default_credentials.json \
  mcp-gdrive:latest
```

### AWS
```bash
docker run -it --rm \
  -v ~/.aws:/home/mcp/.aws:ro \
  -e AWS_PROFILE=default \
  mcp-aws:latest
```

### Notion
```bash
docker run -it --rm \
  -e NOTION_API_KEY=your_notion_api_key \
  mcp-notion:latest
```

### Google Workspace
```bash
docker run -it --rm \
  -p 8000:8000 \
  -v ~/.config/gcloud:/home/mcp/.config/gcloud:ro \
  -e GOOGLE_APPLICATION_CREDENTIALS=/home/mcp/.config/gcloud/application_default_credentials.json \
  mcp-google-workspace:latest
```

## Security Features

All Dockerfiles implement the following security best practices:

1. **Non-root user**: All containers run as non-root users (mcp user with UID 1000)
2. **Minimal base images**: Using slim, Alpine, or distroless images where possible
3. **Multi-stage builds**: Separating build and runtime environments
4. **No unnecessary packages**: Only essential runtime dependencies are included
5. **Health checks**: All containers include health check configurations
6. **Proper signal handling**: Using dumb-init or proper entrypoints for signal handling
7. **Read-only root filesystem**: Can be enabled with `--read-only` flag
8. **No capabilities**: Capabilities are dropped where possible

## Environment Variables

Common environment variables across servers:

- `GOOGLE_APPLICATION_CREDENTIALS`: Path to Google service account credentials
- `AWS_PROFILE`: AWS profile to use for authentication
- `NOTION_API_KEY`: Notion API key for authentication
- `PORT`: Port to expose (default: 8080 or 8000)
- `NODE_ENV`: Node environment (production for Node.js servers)
- `PYTHONUNBUFFERED`: Set to 1 for Python servers for proper logging

## Volumes

Recommended volume mounts:

- Google services: Mount credentials from `~/.config/gcloud`
- AWS: Mount credentials from `~/.aws`
- Application data: Mount to `/app/data` if needed

## Network Security

For production deployment:

1. Use Docker networks to isolate containers
2. Only expose necessary ports
3. Use TLS/SSL for external communication
4. Implement rate limiting at the ingress level
5. Use secrets management for sensitive data

## Monitoring

All containers include health checks. Additional monitoring can be added:

1. Prometheus metrics endpoint
2. Structured logging to stdout/stderr
3. OpenTelemetry instrumentation
4. Custom health check endpoints

## Updates

To update the base images:

1. Check for new base image versions
2. Update the FROM statements
3. Test thoroughly before deploying
4. Consider using image scanning tools