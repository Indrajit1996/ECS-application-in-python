# Multi-stage build for optimized image size
FROM python:3.9-slim as base

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080

# Dynatrace OneAgent environment variables (to be set at runtime via ECS task definition)
ENV DT_API_TOKEN="" \
    DT_ENVIRONMENT_ID="" \
    DT_LOG_CONTENT_ACCESS=1 \
    DT_CONNECTION_POINT=""

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create application directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .
COPY asgi.py .

# NOTE: For ECS deployments, Dynatrace OneAgent should NOT be installed in the container
# Instead, use one of these recommended approaches:
# 1. AWS ECS Integration: Deploy OneAgent as a daemon on ECS hosts
# 2. Dynatrace Operator: Use Kubernetes/ECS Operator for automatic injection
# 3. CodeModules: Use runtime injection via environment variables
#
# For local testing only, we skip OneAgent installation as it requires systemd/init
# which is not available in containers. The application will work without it.

# Create non-root user for security
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Start application with Uvicorn
CMD ["uvicorn", "asgi:asgi_app", "--host", "0.0.0.0", "--port", "8080", "--workers", "4"]
