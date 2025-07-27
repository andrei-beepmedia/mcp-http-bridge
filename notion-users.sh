#!/bin/bash

# Base configuration
URL="http://mcp.dev.beepmedia.com/mcp/notion"
AUTH="beepmedia:9acdab5d85f7ca1973ff8932c73fb9a8e5db434d90465e6c0a61e4b77725837b"

# Initialize and get session
echo "Initializing Notion MCP..."
SESSION_RESPONSE=$(curl -s -X POST \
  -u "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"1.0.0","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}},"id":1}' \
  "$URL" -D -)

SESSION_ID=$(echo "$SESSION_RESPONSE" | grep -i "mcp-session-id:" | cut -d' ' -f2 | tr -d '\r')
echo "Session ID: $SESSION_ID"

# List tools with session
echo -e "\nListing available tools..."
curl -X POST \
  -u "$AUTH" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":2}' \
  "$URL"

echo -e "\n\nSearching for users..."
# Try to search for users
curl -X POST \
  -u "$AUTH" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"search","arguments":{"query":"users"}},"id":3}' \
  "$URL"