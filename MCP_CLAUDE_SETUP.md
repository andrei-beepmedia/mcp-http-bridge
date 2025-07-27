# MCP Claude Setup Guide

## Current Infrastructure Status

### ✅ MCP Server (Dev)
- **URL**: https://mcp.dev.beepmedia.com
- **IP**: 3.215.253.37
- **SSL**: Valid until 2025-10-25
- **Authentication**: Basic Auth
  - Username: `beepmedia`
  - API Key: `9acdab5d85f7ca1973ff8932c73fb9a8e5db434d90465e6c0a61e4b77725837b`

### ✅ Company Website (Dev)
- **URL**: https://dev.beepmedia.com
- **IP**: 44.223.172.20
- **SSL**: Valid until 2025-10-25

### ✅ Company Website (Prod)
- **URL**: https://beepmedia.com
- **IP**: 18.233.201.17
- **Status**: Running, needs SSL setup

### ✅ MCP Server (Prod)
- **URL**: https://mcp.beepmedia.com
- **IP**: 44.206.106.173
- **Status**: EC2 instance stopped

## How to Add MCP Servers to Claude

### For Claude Web (claude.ai)
1. Go to Settings → Connectors
2. Click "Add custom connector"
3. Enter the MCP server URL:
   - For dev: `https://mcp.dev.beepmedia.com/mcp/pdf-reader`
   - For notion: `https://mcp.dev.beepmedia.com/mcp/notion`
   - For AWS: `https://mcp.dev.beepmedia.com/mcp/aws`
4. Configure authentication:
   - Type: Basic Auth
   - Username: `beepmedia`
   - Password: `9acdab5d85f7ca1973ff8932c73fb9a8e5db434d90465e6c0a61e4b77725837b`

### For Claude Desktop
Add to your claude_desktop_config.json:
```json
{
  "mcpServers": {
    "beepmedia-pdf": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://mcp.dev.beepmedia.com/mcp/pdf-reader",
        "--header",
        "Authorization: Basic YmVlcG1lZGlhOjlhY2RhYjVkODVmN2NhMTk3M2ZmODkzMmM3M2ZiOWE4ZTVkYjQzNGQ5MDQ2NWU2YzBhNjFlNGI3NzcyNTgzN2I="
      ]
    }
  }
}
```

## Current Issues

1. **MCP HTTP Bridge**: The bridge service is running but MCP containers need to be properly configured
2. **Nginx Configuration**: Needs updating to properly route MCP requests
3. **Production Setup**: Production MCP server instance is stopped and needs configuration

## Security Notes

- All MCP endpoints require authentication
- SSL certificates are valid and auto-renew
- AWS Security Group properly configured (ports 80, 443, 22 only)
- MCP services run in isolated containers with no network access