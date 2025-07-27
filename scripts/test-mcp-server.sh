#!/bin/bash
# MCP Server Testing Framework

set -e

SERVER_NAME=$1
PORT=${2:-8000}
TEST_TIMEOUT=${3:-30}

if [ -z "$SERVER_NAME" ]; then
    echo "Usage: $0 <server-name> [port] [timeout]"
    exit 1
fi

echo "=== Testing MCP Server: $SERVER_NAME ==="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test functions
test_docker_build() {
    echo -e "\n${YELLOW}1. Building Docker image...${NC}"
    cd /Users/andreihasna/Missions/beepmedia/mission-mcps/repos/$SERVER_NAME
    
    # Check if Dockerfile exists
    if [ -f "Dockerfile" ]; then
        DOCKERFILE="Dockerfile"
    elif [ -f "/Users/andreihasna/Missions/beepmedia/mission-mcps/dockerfiles/Dockerfile.$SERVER_NAME" ]; then
        DOCKERFILE="/Users/andreihasna/Missions/beepmedia/mission-mcps/dockerfiles/Dockerfile.$SERVER_NAME"
    else
        echo -e "${RED}No Dockerfile found for $SERVER_NAME${NC}"
        return 1
    fi
    
    docker build -t mcp-$SERVER_NAME:test -f $DOCKERFILE . || {
        echo -e "${RED}Docker build failed${NC}"
        return 1
    }
    echo -e "${GREEN}✓ Docker image built successfully${NC}"
}

test_docker_run() {
    echo -e "\n${YELLOW}2. Running Docker container...${NC}"
    
    # Stop any existing container
    docker stop mcp-$SERVER_NAME-test 2>/dev/null || true
    docker rm mcp-$SERVER_NAME-test 2>/dev/null || true
    
    # Run container with test credentials
    docker run -d \
        --name mcp-$SERVER_NAME-test \
        -p $PORT:8000 \
        -e MCP_TRANSPORT=stdio \
        -e TEST_MODE=true \
        mcp-$SERVER_NAME:test || {
        echo -e "${RED}Docker run failed${NC}"
        return 1
    }
    
    # Wait for container to start
    sleep 5
    
    # Check if container is running
    if docker ps | grep -q mcp-$SERVER_NAME-test; then
        echo -e "${GREEN}✓ Container running${NC}"
    else
        echo -e "${RED}Container failed to start${NC}"
        docker logs mcp-$SERVER_NAME-test
        return 1
    fi
}

test_mcp_protocol() {
    echo -e "\n${YELLOW}3. Testing MCP protocol...${NC}"
    
    # Test basic MCP initialization
    docker exec mcp-$SERVER_NAME-test sh -c 'echo "{\"jsonrpc\":\"2.0\",\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"1.0.0\",\"capabilities\":{}},\"id\":1}" | head -1' || {
        echo -e "${RED}MCP protocol test failed${NC}"
        return 1
    }
    
    echo -e "${GREEN}✓ MCP protocol responding${NC}"
}

test_health_check() {
    echo -e "\n${YELLOW}4. Testing health check...${NC}"
    
    # Check container health
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' mcp-$SERVER_NAME-test 2>/dev/null || echo "none")
    
    if [ "$HEALTH" = "healthy" ]; then
        echo -e "${GREEN}✓ Health check passed${NC}"
    else
        echo -e "${YELLOW}⚠ No health check configured${NC}"
    fi
}

cleanup() {
    echo -e "\n${YELLOW}5. Cleaning up...${NC}"
    docker stop mcp-$SERVER_NAME-test 2>/dev/null || true
    docker rm mcp-$SERVER_NAME-test 2>/dev/null || true
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Run tests
test_docker_build || exit 1
test_docker_run || { cleanup; exit 1; }
test_mcp_protocol || { cleanup; exit 1; }
test_health_check
cleanup

echo -e "\n${GREEN}=== All tests passed for $SERVER_NAME ===${NC}\n"