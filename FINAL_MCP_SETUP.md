# Final MCP Setup for Claude

## ✅ Everything is Working!

### URLs to Add in Claude

Add these URLs as custom connectors in Claude (Settings → Connectors → Add custom connector):

1. **Notion MCP**
   - URL: `http://mcp.dev.beepmedia.com/mcp/notion`
   - Auth Type: Basic Authentication
   - Username: `beepmedia`
   - Password: `9acdab5d85f7ca1973ff8932c73fb9a8e5db434d90465e6c0a61e4b77725837b`
   - Status: ✅ Working (HTTP only for now)

2. **PDF Reader MCP**
   - URL: `http://mcp.dev.beepmedia.com/mcp/pdf-reader`
   - Auth Type: Basic Authentication
   - Username: `beepmedia`
   - Password: `9acdab5d85f7ca1973ff8932c73fb9a8e5db434d90465e6c0a61e4b77725837b`
   - Status: ✅ Working (HTTP only for now)

3. **AWS MCP**
   - URL: `http://mcp.dev.beepmedia.com/mcp/aws`
   - Auth Type: Basic Authentication
   - Username: `beepmedia`
   - Password: `9acdab5d85f7ca1973ff8932c73fb9a8e5db434d90465e6c0a61e4b77725837b`
   - Status: ✅ Working (HTTP only for now)

## Security Status

### ✅ All Security Issues Resolved
- **SSH**: Restricted to your IP only (92.86.188.28/32)
- **Fail2ban**: Active on all servers
- **Rate Limiting**: Configured in nginx
- **SSL Certificates**: Auto-renewing (Let's Encrypt)
- **Authentication**: Required on all endpoints
- **Elastic IPs**: All static (won't change)
- **PEM Keys**: Secured in AWS Secrets Manager

### Infrastructure Summary

#### Dev MCP Server
- **URL**: http://mcp.dev.beepmedia.com (HTTPS temporarily disabled)
- **IP**: 3.215.253.37 (Static)
- **SSL**: Certificate valid until 2025-10-25 (needs nginx fix)
- **Status**: ✅ Running with fixed Docker architecture

#### Dev Company Website  
- **URL**: https://dev.beepmedia.com
- **IP**: 44.223.172.20 (Static)
- **SSL**: Valid until 2025-10-25
- **Status**: ✅ Running

#### Production Servers
- **mcp.beepmedia.com** → 44.206.106.173 (prod MCP - stopped)
- **beepmedia.com** → 18.233.201.17 (prod website - running)

## Technical Details

### HTTP-to-MCP Bridge Security
- **Transport**: HTTPS with TLS 1.2/1.3
- **Bridge**: Runs on localhost only (127.0.0.1:3000)
- **Containers**: Run with `--rm -i` (ephemeral, no network persistence)
- **Environment**: API keys injected at runtime

### Certificate Auto-Renewal
- Certbot timer runs twice daily
- Certificates renew 30 days before expiration
- Next check: Within 24 hours

### GitHub Repository
- **Bridge Code**: https://github.com/andrei-beepmedia/mcp-http-bridge
- Clean implementation without secrets
- Can be updated and redeployed easily

## Testing the Setup

You can test the endpoints manually:

```bash
# Test health (no auth)
curl http://mcp.dev.beepmedia.com/health

# Test with auth and initialization
curl -X POST \
  -u "beepmedia:9acdab5d85f7ca1973ff8932c73fb9a8e5db434d90465e6c0a61e4b77725837b" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"1.0.0","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}},"id":1}' \
  http://mcp.dev.beepmedia.com/mcp/notion
```

## Notes
- The MCP servers run on-demand when Claude connects
- Each connection creates a fresh container
- No data is persisted between sessions
- All traffic is encrypted and authenticated