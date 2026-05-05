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
make test-fast
make test-unit
make test-integration
make test-e2e
make test-regression
make doctor-aws
make deploy-check
make format
make lint
make docker-build
make docker-run
make ecr-setup
make domain-setup
make domain-status
```

Run `make help` to see the full target list.

## Deployment

The primary deployment target is AWS App Runner backed by ECR and Route 53.

GitHub Actions provides the end-to-end CI/CD path:

- pull requests and pushes run the fast quality gate with `make check`
- pushes to `main` and manual `workflow_dispatch` run `make verify`
- successful release runs build the Docker image, push it to ECR, trigger App Runner deployment, and verify the public `/health` endpoint
- AWS authentication is handled through GitHub OIDC rather than long-lived IAM user keys
- `make deploy-check` gives you a local preflight before shipping: fast quality gate, AWS wiring checks, and a Docker build without pushing

- deployment runbook: [deployment/DEPLOY.md](/home/ricka/Git/RickArkoPortfolio/deployment/DEPLOY.md)
- App Runner notes: [deployment/AppRunner.md](/home/ricka/Git/RickArkoPortfolio/deployment/AppRunner.md)
- custom domain notes: [deployment/CustomDomain.md](/home/ricka/Git/RickArkoPortfolio/deployment/CustomDomain.md)

## Ship A Release

The repo supports two deployment paths:

1. Preferred: GitHub Actions CI/CD
2. Emergency/manual: local terminal deploy from WSL

### Preferred release flow

```bash
make deploy-check
git push
```

Then:

1. open a pull request
2. let GitHub Actions run `make check`
3. merge to `main`
4. let GitHub Actions run `make verify`, publish the image to ECR, trigger App Runner, and validate `https://rickarko.com/health`

### Manual release flow

Use this when you intentionally need to ship from your local machine.

```bash
make deploy-check
make ecr-setup
aws apprunner start-deployment --service-arn "$APPRUNNER_SERVICE_ARN" --region us-east-1
```

Then watch the deployment and verify the health contract:

```bash
watch -n 5 "aws apprunner list-operations --service-arn \"$APPRUNNER_SERVICE_ARN\" --region us-east-1 --query 'OperationSummaryList[0].[Status,Type]' --output table"
curl -i https://rickarko.com/health
```

Success means:

- App Runner operation status becomes `SUCCEEDED`
- `/health` returns `application/json`
- response body is `{"status":"ok"}`


### Manual Alternatives _(if ever needed)_:
  - Re-trigger the same workflow: `gh run rerun 25203824177 --repo RickArko/RickArkoPortfolio`
  - Trigger workflow_dispatch against any commit: `gh workflow run "Portfolio CI/CD" --ref main --repo RickArko/RickArkoPortfolio`
  - Direct App Runner deploy (skip CI): `aws apprunner start-deployment --service-arn "$APPRUNNER_SERVICE_ARN" --region us-east-1`


## Project structure

```text
.
├── src/
│   ├── rickarko_portfolio/  Installable Flask package, app factory, SEO, config
│   ├── db/                  JSON-backed site content
│   ├── templates/           Jinja templates
│   └── static/              CSS, JS, and images
├── tests/
│   ├── unit/                Pure helper and config tests
│   ├── integration/         App factory and wiring tests
│   ├── end_to_end/          HTTP-first rendered route tests
│   └── regression/          Deployment/runtime contract tests
├── deployment/bin/       Linux-first deployment scripts
├── deployment/windows/   Archived Windows legacy scripts
├── Dockerfile            Container build
├── apprunner.yaml        AWS App Runner config
└── Makefile              Main local/deployment entrypoint
```

## Testing philosophy

The repo uses pytest as the single test runner and treats "end to end" as
HTTP-first validation of the real Flask application, not browser automation.

- `make test-fast` covers unit and integration paths for quick iteration
- `make test-e2e` exercises public rendered pages and crawlability contracts
- `make test-regression` protects WSGI, entrypoint, and deployment-sensitive behavior
- `make test` runs the full suite with coverage enforcement on the Python package
