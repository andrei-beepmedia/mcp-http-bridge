# MCP Authentication Information

## Access Credentials
- **Username**: beepmedia
- **API Key**: 9acdab5d85f7ca1973ff8932c73fb9a8e5db434d90465e6c0a61e4b77725837b

## Endpoints

### Development (dev.mcp.beepmedia.com)
- **IP**: 3.215.253.37
- **HTTPS**: https://dev.mcp.beepmedia.com
- **Health Check**: https://dev.mcp.beepmedia.com/health (no auth required)
- **MCP Services** (auth required):
  - AWS: https://dev.mcp.beepmedia.com/aws/
  - PDF Reader: https://dev.mcp.beepmedia.com/pdf-reader/
  - Notion: https://dev.mcp.beepmedia.com/notion/

### Production (mcp.beepmedia.com)
- **IP**: 44.206.106.173
- **Status**: EC2 instance is currently stopped
- **DNS**: Configured and pointing to production IP

## Usage Example
```bash
# Using curl with basic auth
curl -u "beepmedia:9acdab5d85f7ca1973ff8932c73fb9a8e5db434d90465e6c0a61e4b77725837b" https://dev.mcp.beepmedia.com/aws/

# Using Authorization header
curl -H "Authorization: Basic YmVlcG1lZGlhOjlhY2RhYjVkODVmN2NhMTk3M2ZmODkzMmM3M2ZiOWE4ZTVkYjQzNGQ5MDQ2NWU2YzBhNjFlNGI3NzcyNTgzN2I=" https://dev.mcp.beepmedia.com/aws/
```

## Security Notes
- Basic HTTP authentication is enabled on all MCP endpoints
- SSL/TLS certificate is valid until 2025-10-24
- The health check endpoint is publicly accessible for monitoring
- All other endpoints require authentication