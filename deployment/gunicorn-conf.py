import multiprocessing
from pathlib import Path

base_dir = Path(__file__).parent.parent.resolve()
worker_nodes = multiprocessing.cpu_count() * 2 + 1

chdir = str(base_dir)
pythonpath = str(base_dir / "src")
bind = "0.0.0.0:8080"
workers = worker_nodes

# Production logging: stdout/stderr for container log collection
accesslog = "-"
errorlog = "-"
loglevel = "info"

# Production timeouts
graceful_timeout = 30
timeout = 120
