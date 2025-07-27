#!/bin/bash

# Test MCP endpoint remotely
URL="http://mcp.dev.beepmedia.com/mcp/notion"
AUTH="beepmedia:9acdab5d85f7ca1973ff8932c73fb9a8e5db434d90465e6c0a61e4b77725837b"

# Initialize request
INIT_REQUEST='{
  "jsonrpc": "2.0",
  "method": "initialize",
  "params": {
    "protocolVersion": "1.0.0",
    "capabilities": {},
    "clientInfo": {
      "name": "test-client",
      "version": "1.0"
    }
  },
  "id": 1
}'

echo "Testing MCP Notion endpoint..."
curl -X POST \
  -u "$AUTH" \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -d "$INIT_REQUEST" \
  "$URL" \
  --max-time 5