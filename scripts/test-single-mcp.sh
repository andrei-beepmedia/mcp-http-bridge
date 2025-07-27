#!/bin/bash
# Test a single MCP server

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🧪 MCP Server Test Runner"
echo "========================"

# Function to test AWS MCP
test_aws_mcp() {
    echo -e "\n${YELLOW}Testing AWS Core MCP Server...${NC}"
    cd /Users/andreihasna/Missions/beepmedia/mission-mcps/repos/mcp-aws/src/core-mcp-server
    
    # Build
    echo "Building Docker image..."
    docker build -t mcp-aws-core:test . || {
        echo -e "${RED}❌ Build failed${NC}"
        return 1
    }
    
    # Test
    echo "Testing MCP protocol..."
    echo '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"1.0.0","capabilities":{}},"id":1}' | \
    docker run -i --rm \
        -e AWS_ACCESS_KEY_ID=test \
        -e AWS_SECRET_ACCESS_KEY=test \
        -e AWS_REGION=us-east-1 \
        mcp-aws-core:test && echo -e "${GREEN}✅ AWS Core MCP test passed${NC}" || echo -e "${RED}❌ Test failed${NC}"
}

# Function to test Notion MCP
test_notion_mcp() {
    echo -e "\n${YELLOW}Testing Notion MCP Server...${NC}"
    cd /Users/andreihasna/Missions/beepmedia/mission-mcps/repos/mcp-notion
    
    # Build
    echo "Building Docker image..."
    docker build -t mcp-notion:test . || {
        echo -e "${RED}❌ Build failed${NC}"
        return 1
    }
    
    # Test
    echo "Testing MCP protocol..."
    echo '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"1.0.0","capabilities":{}},"id":1}' | \
    docker run -i --rm \
        -e NOTION_API_KEY=secret_test_123 \
        mcp-notion:test && echo -e "${GREEN}✅ Notion MCP test passed${NC}" || echo -e "${RED}❌ Test failed${NC}"
}

# Function to test Slack MCP
test_slack_mcp() {
    echo -e "\n${YELLOW}Testing Slack MCP Server...${NC}"
    cd /Users/andreihasna/Missions/beepmedia/mission-mcps/repos/mcp-slack
    
    # Build
    echo "Building Docker image..."
    docker build -t mcp-slack:test . || {
        echo -e "${RED}❌ Build failed${NC}"
        return 1
    }
    
    # Test
    echo "Testing MCP protocol..."
    echo '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"1.0.0","capabilities":{}},"id":1}' | \
    docker run -i --rm \
        -e SLACK_BOT_TOKEN=xoxb-test \
        -e SLACK_APP_TOKEN=xapp-test \
        mcp-slack:test && echo -e "${GREEN}✅ Slack MCP test passed${NC}" || echo -e "${RED}❌ Test failed${NC}"
}

# Function to test PDF Reader MCP
test_pdf_mcp() {
    echo -e "\n${YELLOW}Testing PDF Reader MCP Server...${NC}"
    cd /Users/andreihasna/Missions/beepmedia/mission-mcps/repos/mcp-pdf-reader
    
    # Build
    echo "Building Docker image..."
    docker build -t mcp-pdf:test . || {
        echo -e "${RED}❌ Build failed${NC}"
        return 1
    }
    
    # Test
    echo "Testing MCP protocol..."
    echo '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"1.0.0","capabilities":{}},"id":1}' | \
    docker run -i --rm mcp-pdf:test && echo -e "${GREEN}✅ PDF MCP test passed${NC}" || echo -e "${RED}❌ Test failed${NC}"
}

# Run specific test based on argument
case "$1" in
    aws)
        test_aws_mcp
        ;;
    notion)
        test_notion_mcp
        ;;
    slack)
        test_slack_mcp
        ;;
    pdf)
        test_pdf_mcp
        ;;
    all)
        test_aws_mcp
        test_notion_mcp
        test_slack_mcp
        test_pdf_mcp
        ;;
    *)
        echo "Usage: $0 {aws|notion|slack|pdf|all}"
        exit 1
        ;;
esac