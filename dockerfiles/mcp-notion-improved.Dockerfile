# syntax=docker/dockerfile:1

# Use Node.js 20 LTS Alpine for smaller image size
FROM node:20-alpine AS builder

# Install build dependencies
RUN apk add --no-cache python3 make g++

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies with npm ci for reproducible builds
RUN --mount=type=cache,target=/root/.npm \
    npm ci --ignore-scripts --omit=dev

# Copy source code
COPY . .

# Build the package
RUN --mount=type=cache,target=/root/.npm \
    npm run build

# Runtime stage - use distroless for minimal attack surface
FROM gcr.io/distroless/nodejs20-debian12

# Copy built application from builder
COPY --from=builder /app/node_modules /app/node_modules
COPY --from=builder /app/dist /app/dist
COPY --from=builder /app/bin /app/bin
COPY --from=builder /app/scripts/notion-openapi.json /app/scripts/notion-openapi.json
COPY --from=builder /app/package.json /app/package.json

# Set working directory
WORKDIR /app

# Set environment variables
ENV NODE_ENV=production
ENV OPENAPI_MCP_HEADERS="{}"

# Health check using Node.js
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD ["node", "-e", "require('http').get('http://localhost:8080/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1); }).on('error', () => { process.exit(1); })"]

# Expose port
EXPOSE 8080

# Entry point - distroless runs as non-root by default
ENTRYPOINT ["node", "/app/bin/cli.mjs"]