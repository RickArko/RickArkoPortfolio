# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with this repository.

## Project Overview

Flask-based personal portfolio website for Rick Arko. Content is JSON-backed and rendered with Jinja templates. The site is deployed via Docker on AWS App Runner.

- **Live:** https://rickarko.com
- **App Runner URL:** https://ctydyem9cj.us-east-1.awsapprunner.com
- **Region:** us-east-1

## Linux-first workflow

This repo is Linux-first.

- use Bash and the top-level `Makefile`
- use WSL on Windows instead of native PowerShell
- treat `deployment/windows/legacy/` as archived reference material only

## Development Commands

```bash
# Install dependencies
make install

# Run locally (debug mode, port 8080)
make dev

# Fast layered test runs
make test-fast
make test-unit
make test-integration
make test-e2e
make test-regression

# Run with Docker
make docker-build
make docker-run

# Format and lint
make format
make lint

# Run tests
make test
```

## Deployment Commands

```bash
# Build and push the image to ECR
make ecr-setup

# Associate or repair the custom domain in App Runner / Route 53
make domain-setup

# Inspect current custom-domain status
make domain-status
```

## Architecture

**Stack:** Python 3.11, Flask, Gunicorn, Jinja2 templates, custom CSS/JS, package management via `uv`.

**Package entrypoint:** `src/rickarko_portfolio/factory.py` owns the Flask app factory. `src/rickarko_portfolio/wsgi.py` exposes `app` and `application` for WSGI servers. `python -m rickarko_portfolio` is the canonical local dev entrypoint. `src/app.py` is now a temporary compatibility shim.

**Routes:** `/`, `/experience/`, `/projects/`, `/blog/`, `/contact/`, `/health`, `/robots.txt`, `/sitemap.xml`.

**Data layer:** No database. Portfolio content lives in `src/db/` as JSON files and is loaded through typed helpers in `src/rickarko_portfolio/content.py`.

**Templates:** `src/templates/base.html` is the main layout. Static assets live in `src/static/`.

**Deployment:** `Dockerfile` builds the app image. `apprunner.yaml` configures AWS App Runner. Linux-first deployment scripts live in `deployment/bin/`.

**Testing:** Pytest is the only test runner. The suite is split into `tests/unit`, `tests/integration`, `tests/end_to_end`, and `tests/regression`, with coverage enforced against the `rickarko_portfolio` package.

**Image utilities:** `src/resize_profile_image.py` uses Pillow to crop profile images and generate favicons.
