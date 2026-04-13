"""Compatibility shim for legacy entrypoints.

This module remains in place so older scripts that still target ``src/app.py``
continue to boot the package-based application while the rest of the repo
converges on ``rickarko_portfolio.wsgi`` and ``python -m rickarko_portfolio``.
"""

from rickarko_portfolio.__main__ import main
from rickarko_portfolio.wsgi import app as app
from rickarko_portfolio.wsgi import application as application

__all__ = ["app", "application", "main"]


if __name__ == "__main__":
    main()
