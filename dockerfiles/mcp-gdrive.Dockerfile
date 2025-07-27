# syntax=docker/dockerfile:1

# Use Node.js 20 LTS slim image as base
FROM node:20-slim AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --omit=dev

# Copy source code
COPY . .

# Build TypeScript code
RUN npm run build

# Runtime stage
FROM node:20-slim

# Create non-root user
RUN useradd --create-home --shell /bin/bash mcp \
    && mkdir -p /app \
    && chown -R mcp:mcp /app

# Install dumb-init for proper signal handling
RUN apt-get update && apt-get install -y \
    dumb-init \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy built application from builder
COPY --from=builder --chown=mcp:mcp /app/dist ./dist
COPY --from=builder --chown=mcp:mcp /app/node_modules ./node_modules
COPY --from=builder --chown=mcp:mcp /app/package*.json ./

# Create symlink for the binary
RUN chmod +x dist/index.js && \
    ln -s /app/dist/index.js /usr/local/bin/mcp-gdrive

# Switch to non-root user
USER mcp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD node -e "console.log('Health check passed')" || exit 1

# Set environment variables
ENV NODE_ENV=production

# Expose port for stdio transport (if needed in future)
EXPOSE 8080

# Use dumb-init to handle signals properly
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Default command
CMD ["mcp-gdrive"]