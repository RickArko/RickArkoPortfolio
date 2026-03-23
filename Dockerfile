# --- Stage 1: Builder ---
FROM python:3.11-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -Ls https://astral.sh/uv/install.sh | bash
ENV PATH="/root/.local/bin:$PATH"

WORKDIR /opt/portfolio

COPY pyproject.toml uv.lock ./
RUN uv sync --no-dev

# --- Stage 2: Runtime ---
FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/portfolio

# Copy the virtual environment from builder
COPY --from=builder /opt/portfolio/.venv ./.venv

# Copy application files
COPY deployment ./deployment
COPY src ./src

# Create logs directory
RUN mkdir -p logs

# Add non-root user
RUN groupadd -r appuser && useradd -r -g appuser -d /opt/portfolio appuser \
    && chown -R appuser:appuser /opt/portfolio
USER appuser

# Set working directory for module imports
WORKDIR /opt/portfolio/src

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

EXPOSE 8080
CMD ["/opt/portfolio/.venv/bin/gunicorn", "-c", "/opt/portfolio/deployment/gunicorn-conf.py", "app:app"]
