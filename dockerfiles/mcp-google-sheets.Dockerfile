# syntax=docker/dockerfile:1

# Use Python 3.11 slim image as base
FROM python:3.11-slim AS builder

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency files
COPY pyproject.toml README.md ./
COPY src ./src

# Install uv for faster dependency management
RUN pip install --no-cache-dir uv

# Install dependencies and the package
RUN uv pip install --system --no-cache .

# Runtime stage
FROM python:3.11-slim

# Create non-root user
RUN useradd --create-home --shell /bin/bash mcp \
    && mkdir -p /app \
    && chown -R mcp:mcp /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Python packages from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin/mcp-google-sheets /usr/local/bin/mcp-google-sheets

# Set working directory
WORKDIR /app

# Switch to non-root user
USER mcp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD python -c "import mcp_google_sheets; print('Health check passed')" || exit 1

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Expose port for stdio transport (if needed in future)
EXPOSE 8080

# Default command
ENTRYPOINT ["mcp-google-sheets"]
CMD ["--transport", "stdio"]