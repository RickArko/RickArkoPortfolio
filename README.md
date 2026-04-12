# Rick Arko Portfolio Website

Flask portfolio site for Rick Arko, positioned as an AI/ML consultant and founder profile.

## Linux-first workflow

This repository now treats Bash as the only supported automation layer.

- use the top-level `Makefile`
- use Bash scripts from `deployment/bin/`
- if you are on Windows, run the repo through WSL
- old PowerShell scripts live in `deployment/windows/legacy/` and are deprecated

## Quick start

```bash
make install
make dev
```

The local app runs on `http://localhost:8080`.

## Common commands

```bash
make test
make format
make docker-build
make docker-run
make ecr-setup
make domain-setup
make domain-status
```

Run `make help` to see the full target list.

## Deployment

The primary deployment target is AWS App Runner backed by ECR and Route 53.

- deployment runbook: [deployment/DEPLOY.md](/home/ricka/Git/RickArkoPortfolio/deployment/DEPLOY.md)
- App Runner notes: [deployment/AppRunner.md](/home/ricka/Git/RickArkoPortfolio/deployment/AppRunner.md)
- custom domain notes: [deployment/CustomDomain.md](/home/ricka/Git/RickArkoPortfolio/deployment/CustomDomain.md)

## Project structure

```text
.
├── src/                  Flask app, templates, and JSON content
├── tests/                Route smoke tests
├── deployment/bin/       Linux-first deployment scripts
├── deployment/windows/   Archived Windows legacy scripts
├── Dockerfile            Container build
├── apprunner.yaml        AWS App Runner config
└── Makefile              Main local/deployment entrypoint
```
