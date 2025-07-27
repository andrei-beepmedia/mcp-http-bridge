#!/bin/bash
# Create GitHub repositories for MCP servers

set -e

echo "🐙 Creating GitHub repositories for MCP servers"
echo "=============================================="

# GitHub organization/user
GH_USER="andrei-beepmedia"

# List of MCP servers to create repos for
MCP_SERVERS=(
    "mcp-aws"
    "mcp-notion"
    "mcp-pdf-reader"
    "mcp-openai"
    "mcp-firecrawl"
    "mcp-elevenlabs"
    "mcp-redis"
)

# Create repos and push code
for server in "${MCP_SERVERS[@]}"; do
    echo ""
    echo "📦 Processing $server..."
    
    # Check if repo exists
    if gh repo view "$GH_USER/$server" &>/dev/null; then
        echo "   ✓ Repository already exists"
    else
        echo "   Creating repository..."
        gh repo create "$GH_USER/$server" \
            --public \
            --description "MCP (Model Context Protocol) server for ${server#mcp-}" \
            --add-readme
    fi
    
    # Prepare code directory
    cd "/Users/andreihasna/Missions/beepmedia/mission-mcps/repos/$server"
    
    # Initialize git if needed
    if [ ! -d .git ]; then
        git init
    fi
    
    # Create .gitignore if it doesn't exist
    if [ ! -f .gitignore ]; then
        cat > .gitignore << 'EOF'
# Environment files
.env
.env.*
!.env.example

# Node
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
ENV/
.venv

# Docker
*.tar.gz

# Keys and secrets
*.pem
*.key
*.crt
*.cert
*_key
*_secret
*credentials*

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
logs/
*.log

# Build
dist/
build/
*.egg-info/
EOF
    fi
    
    # Create .env.example if needed
    if [ ! -f .env.example ]; then
        case "$server" in
            "mcp-aws")
                cat > .env.example << 'EOF'
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here
AWS_REGION=us-east-1
EOF
                ;;
            "mcp-notion")
                cat > .env.example << 'EOF'
NOTION_API_KEY=your_notion_api_key_here
EOF
                ;;
            "mcp-openai")
                cat > .env.example << 'EOF'
OPENAI_API_KEY=your_openai_api_key_here
EOF
                ;;
            "mcp-firecrawl")
                cat > .env.example << 'EOF'
FIRECRAWL_API_KEY=your_firecrawl_api_key_here
EOF
                ;;
            "mcp-elevenlabs")
                cat > .env.example << 'EOF'
ELEVENLABS_API_KEY=your_elevenlabs_api_key_here
EOF
                ;;
            "mcp-redis")
                cat > .env.example << 'EOF'
REDIS_URL=redis://localhost:6379
EOF
                ;;
        esac
    fi
    
    # Add remote if not exists
    if ! git remote | grep -q origin; then
        git remote add origin "https://github.com/$GH_USER/$server.git"
    else
        git remote set-url origin "https://github.com/$GH_USER/$server.git"
    fi
    
    # Stage and commit
    git add -A
    git commit -m "Initial commit: $server MCP implementation

- Docker support included
- Environment variables configured via .env file
- See .env.example for required configuration
- Part of Beepmedia MCP infrastructure
" || echo "   No changes to commit"
    
    # Push to GitHub
    echo "   Pushing to GitHub..."
    git push -u origin main || git push -u origin master || echo "   Push failed - may need manual intervention"
    
    echo "   ✅ $server processed"
done

echo ""
echo "✅ All repositories created/updated!"
echo ""
echo "Repository URLs:"
for server in "${MCP_SERVERS[@]}"; do
    echo "  https://github.com/$GH_USER/$server"
done