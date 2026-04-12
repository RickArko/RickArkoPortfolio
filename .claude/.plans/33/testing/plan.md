# Plan: `End to End Testing Suite`

## Summary

- Replace the minimal route-smoke suite with a layered pytest strategy that reads as production-grade Python ownership.
- Keep pytest as the single test runner.
- Define "end to end" as HTTP-first, full-stack validation of the Flask app and rendered pages, not browser automation.
- Align the suite with the package/app-factory refactor so config loading, SEO contracts, deployment health checks, and the WSGI entrypoint are all testable through stable fixtures.

## Target Test Layers

- `unit`
  - settings loading and normalization
  - content parsing and caching behavior
  - SEO/canonical/schema helpers
- `integration`
  - app factory wiring
  - route registration
  - request context and URL generation
  - environment override behavior
- `end_to_end`
  - homepage, experience, projects, blog, contact, 404, health, robots, sitemap
  - rendered copy, status codes, content types, canonical URLs, SEO tags, and static asset references
- `regression`
  - WSGI import contract
  - module entrypoint boot behavior
  - deployment-sensitive env overrides for sitemap and robots

## Implementation Notes

- Replace `tests/test_app.py` smoke tests with a directory-based suite:
  - `tests/unit`
  - `tests/integration`
  - `tests/end_to_end`
  - `tests/regression`
- Replace `sys.path` mutation in test bootstrap with package-based imports and app-factory fixtures.
- Standardize shared fixtures for:
  - app creation
  - test client
  - CLI runner
  - request context
  - deterministic environment defaults
  - cache reset between tests
- Keep tests deterministic and fast:
  - no external network calls
  - no browser automation
  - no timing-dependent assertions

## Comprehensive End-to-End Coverage

- Validate real user-visible behavior across the full request path:
  - homepage
  - experience
  - projects
  - blog
  - contact
  - 404
  - health
  - `robots.txt`
  - `sitemap.xml`
- Assert:
  - status code and MIME type
  - canonical URL behavior
  - title and description metadata
  - Open Graph tags
  - JSON-LD on the home page
  - navigation and internal links
  - critical static asset references
  - JSON-backed content rendering
  - branded 404 behavior without stack traces
  - crawlability and sitemap structure

## CI and Quality Gates

- GitHub Actions should run the same pytest contract as local development.
- Support both fast and full feedback paths:
  - fast suite on pull requests and general pushes
  - full suite with coverage on `main` before build/deploy jobs
- Enforce package coverage at `90%` or higher.
- Treat broken regression, integration, or end-to-end tests as deployment blockers.

## End-to-End Deployment Pipeline

- Define a clear release path from merge to production:
  1. pull request runs the fast quality gate
  2. merge to `main` runs full verification with coverage
  3. Docker image is built and tagged with both commit SHA and `latest`
  4. image is pushed to ECR
  5. App Runner deployment is triggered
  6. deployment operation is polled until it succeeds or fails
  7. public `/health` endpoint is checked after deploy
- Support both automatic and intentional release entrypoints:
  - automatic on `push` to `main`
  - manual via GitHub Actions `workflow_dispatch`
- Add deployment-safety features to the workflow:
  - concurrency control to prevent overlapping deploys
  - explicit job stages so failures are easy to localize
  - GitHub Actions step summaries for build, publish, and deploy visibility
- Document the required deployment secrets:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_REGION`
  - `ECR_REPOSITORY`
  - `APPRUNNER_SERVICE_ARN`

## Delivered In This Refactor

- Introduced an installable `rickarko_portfolio` package with a real app factory and WSGI entrypoint.
- Added stable pytest fixtures in `tests/conftest.py`.
- Replaced route smoke tests with layered `unit`, `integration`, `end_to_end`, and `regression` suites.
- Added pytest markers, coverage configuration, and marker-specific `make` targets.
- Updated CI/CD to run fast checks broadly, full verification on `main`, build and publish the release image, trigger App Runner deployment, and perform a post-deploy health check.

## Verification

- `uv run pytest`
- `make test`
- `make test-fast`
- `make test-e2e`
- `make test-regression`
