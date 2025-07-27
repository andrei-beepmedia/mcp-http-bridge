# syntax=docker/dockerfile:1

# Use Python 3.11 Alpine for smaller image size
FROM python:3.11-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    libffi-dev \
    openssl-dev

# Set working directory
WORKDIR /app

# Install uv for faster dependency management
RUN pip install --no-cache-dir uv

# Copy dependency files
COPY pyproject.toml uv.lock ./

# Install Python dependencies
RUN uv pip install --system --no-cache \
    fastapi>=0.115.12 \
    fastmcp>=2.3.3 \
    google-api-python-client>=2.168.0 \
    google-auth-httplib2>=0.2.0 \
    google-auth-oauthlib>=1.2.2 \
    httpx>=0.28.1 \
    "mcp[cli]>=1.6.0" \
    sse-starlette>=2.3.3 \
    uvicorn>=0.34.2 \
    pyjwt>=2.10.1 \
    tomlkit \
    ruff>=0.12.4

# Copy application code
COPY . .

# Runtime stage
FROM python:3.11-alpine

# Install runtime dependencies
RUN apk add --no-cache \
    curl \
    ca-certificates \
    && addgroup -g 1000 -S mcp \
    && adduser -u 1000 -S mcp -G mcp

# Copy Python packages from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin/* /usr/local/bin/

# Set working directory
WORKDIR /app

# Copy application code
COPY --chown=mcp:mcp . .

# Create placeholder client_secrets.json for lazy loading capability
RUN echo '{"installed":{"client_id":"placeholder","client_secret":"placeholder","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","redirect_uris":["http://localhost:8000/oauth2callback"]}}' > /app/client_secrets.json \
    && chown mcp:mcp /app/client_secrets.json

# Switch to non-root user
USER mcp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8000}/health || exit 1

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PORT=8000

# Expose port
EXPOSE 8000

# Command to run the application
CMD ["python", "main.py", "--transport", "streamable-http"]