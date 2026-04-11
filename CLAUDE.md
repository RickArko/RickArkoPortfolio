# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flask-based personal portfolio website for Rick Arko. Serves pages with JSON-backed content (no database). Deployed via Docker on AWS App Runner.

- **Live:** https://rickarko.com (also https://www.rickarko.com)
- **App Runner URL:** https://ctydyem9cj.us-east-1.awsapprunner.com
- **Region:** us-east-1

## Development Commands

```bash
# Install dependencies
uv sync --dev

# Run locally (debug mode, port 8080)
uv run src/app.py

# Run with Docker
docker build -t rickarkoportfolio .
docker run -p 8080:8080 rickarkoportfolio

# Production server (gunicorn)
uv run gunicorn -w 4 -b 0.0.0.0:8080 --chdir src app:app

# Format code
uv run black src/
uv run isort src/

# Run tests
uv run pytest
```

## Architecture

**Stack:** Python 3.11, Flask, Gunicorn, Jinja2 templates, Bootstrap 4, jQuery. Package management via `uv`.

**Entry point:** `src/app.py` — defines Flask routes and exposes `application = app` for WSGI servers.

**Routes:** `/` (home), `/experience/`, `/projects/`, `/blog/` — each loads data from `src/db/*.json` and renders a Jinja2 template. 404 has a custom handler.

**Data layer:** No database. Portfolio content lives in `src/db/` as JSON files (`home.json`, `experience.json`, `projects.json`, `contact.json`). Routes load these via paths resolved in `src/constants.py`.

**Path resolution:** `src/constants.py` uses `get_data_dir()` to locate `db/` relative to the file, CWD, or `src/` subdirectory — this handles running from different contexts (Docker, local, gunicorn).

**Templates:** `src/templates/base.html` is the master layout with sidebar nav. Pages extend it. Static assets in `src/static/`.

**Deployment:** `Dockerfile` builds with `python:3.10-slim` + uv. `apprunner.yaml` configures AWS App Runner (docker runtime, port 8080). `deployment/gunicorn-conf.py` provides production gunicorn config with dynamic worker count.

**Image utilities:** `src/resize_profile_image.py` uses Pillow to crop profile images and generate favicons.
