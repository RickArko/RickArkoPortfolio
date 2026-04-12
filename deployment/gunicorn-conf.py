import os
from pathlib import Path

base_dir = Path(__file__).parent.parent.resolve()
default_workers = "3"

chdir = str(base_dir)
pythonpath = str(base_dir / "src")
bind = "0.0.0.0:8080"

# Container runtimes can expose the host CPU count, which massively overstates
# safe worker concurrency for a small App Runner service. Use a predictable
# default and allow explicit override when needed.
workers = int(os.getenv("WEB_CONCURRENCY", default_workers))

# Production logging: stdout/stderr for container log collection
accesslog = "-"
errorlog = "-"
loglevel = "info"

# Production timeouts
graceful_timeout = 30
timeout = 120
