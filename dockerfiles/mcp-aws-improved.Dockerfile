# syntax=docker/dockerfile:1

# Use specific Python version with hash for security
FROM python:3.13-slim-bookworm@sha256:6544e0e002b40ae0f59bc3618b07c1e48064c4faed3a15ae2fbd2e8f663e8283 AS builder

# Set working directory
WORKDIR /app

# Enable bytecode compilation
ENV UV_COMPILE_BYTECODE=1

# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy

# Prefer the system python
ENV UV_PYTHON_PREFERENCE=only-system

# Run without updating the uv.lock file like running with --frozen
ENV UV_FROZEN=true

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy the required files first
COPY pyproject.toml uv.lock uv-requirements.txt ./

# Install dependencies using pip with hash verification
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --require-hashes --requirement uv-requirements.txt --no-cache-dir && \
    pip install uv && \
    uv sync --python 3.13 --frozen --no-install-project --no-dev --no-editable

# Copy the rest of the project and install it
COPY . /app
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --python 3.13 --frozen --no-dev --no-editable

# Runtime stage
FROM python:3.13-slim-bookworm@sha256:6544e0e002b40ae0f59bc3618b07c1e48064c4faed3a15ae2fbd2e8f663e8283

# Install runtime dependencies and create non-root user
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    procps \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 1000 mcp \
    && useradd --uid 1000 --gid mcp --shell /bin/bash --create-home mcp

# Set working directory
WORKDIR /app

# Copy application from builder
COPY --from=builder --chown=mcp:mcp /app/.venv /app/.venv

# Copy healthcheck script
COPY --chown=mcp:mcp ./docker-healthcheck.sh /usr/local/bin/docker-healthcheck.sh
RUN chmod +x /usr/local/bin/docker-healthcheck.sh

# Set PATH to include virtual environment
ENV PATH="/app/.venv/bin:$PATH"

# Security: Drop all capabilities
RUN setcap -r /app/.venv/bin/python3.13 || true

# Switch to non-root user
USER mcp

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=10s --retries=3 \
    CMD ["docker-healthcheck.sh"]

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Expose port (if needed)
EXPOSE 8080

# Entry point
ENTRYPOINT ["awslabs.aws-api-mcp-server"]