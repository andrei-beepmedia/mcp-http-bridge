#!/bin/sh
# Generic startup script that loads secrets and starts MCP server

# Load secrets from mounted volume
if [ -f /secrets/$(basename $0 .sh).json ]; then
    # Export each secret as environment variable
    export $(cat /secrets/$(basename $0 .sh).json | jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]')
fi

# Start the actual MCP server
exec "$@"