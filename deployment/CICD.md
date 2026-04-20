# CI/CD — Hardened Implementation Plan

> **Scope:** ship `rickarko.com` safely from any feature branch with one command, while making the rigor of the pipeline itself a visible signal of engineering competency.
>
> **Guiding principle:** trunk-based + ephemeral previews + auto-rollback. No long-lived `develop` branch. No permanent staging service. No IaC rewrite. Machinery matches blast radius.

---

## 1. Target architecture

```
feature/*  ──►  PR  ──►  [CI: make check + build + ephemeral preview]  ──►  reviewer sees preview URL
                                                                                │
                                                                                ▼
                                                                       squash merge to main
                                                                                │
                                                                                ▼
                               [CI: make verify → push ECR → capture prev digest → deploy →
                                smoke-test /,/projects/,/sitemap.xml,/health → rollback on fail]
                                                                                │
                                                                                ▼
                                                                         rickarko.com live
```

- **One long-lived branch:** `main`. Trunk-based.
- **One permanent environment:** production (`rickarko.com`).
- **Ephemeral preview per PR:** temporary App Runner service, torn down on PR close.
- **Zero-touch rollback:** CI captures the previous good image digest pre-deploy and restores it if post-deploy smoke tests fail.

### Why this shape

- Matches how Shopify / Vercel / Linear ship — trunk-based with per-PR previews is the current industry default, not GitFlow.
- A permanent `dev.rickarko.com` costs ~$25–50/mo idle and papers over weak tests. Ephemeral previews give the same review benefit, scoped to a change, at ~$0 idle.
- Auto-rollback + HTTP smoke tests demonstrate MTTR thinking — the exact instinct hiring panels probe for in platform/ML-infra roles.

---

## 2. Deliverables

| # | Artifact | Purpose |
|---|----------|---------|
| 1 | `deployment/bin/smoke-test.sh` | Post-deploy HTTP contract validation against a base URL |
| 2 | `deployment/bin/rollback.sh` | Retag previous image digest as `latest` and redeploy |
| 3 | `deployment/bin/preview-create.sh` | Create ephemeral App Runner service for a PR |
| 4 | `deployment/bin/preview-destroy.sh` | Delete ephemeral preview service |
| 5 | `.github/workflows/deploy.yml` (extend) | Add digest capture, smoke test, rollback on failure |
| 6 | `.github/workflows/pr-preview.yml` (new) | Build `:pr-<num>` image, spin preview, comment URL, destroy on close |
| 7 | `Makefile` (extend) | `make ship`, `make smoke-test`, `make rollback`, `make preview-*` |
| 8 | `tests/regression/test_smoke_contract.py` (new) | Parity check: smoke-test.sh asserts the same snippets as `test_routes.py::HTML_PAGES` |
| 9 | `deployment/DEPLOY.md` (update) | Document the new flow + rollback runbook |

---

## 3. Component specs

### 3.1 `smoke-test.sh`

**Contract:** given a base URL, exits non-zero if any public route fails to return its expected HTTP contract.

```bash
deployment/bin/smoke-test.sh <BASE_URL>
# e.g. deployment/bin/smoke-test.sh https://rickarko.com
```

- Reuses the `HTML_PAGES` table from `tests/end_to_end/test_routes.py` as the source of truth (mirrored in bash — see §5 for drift protection).
- Checks per route: HTTP 200, `content-type: text/html`, `<title>` match, canonical link present, snippet present in body.
- Also checks: `/health` → `{"status":"ok"}`, `/robots.txt` contains `Sitemap:`, `/sitemap.xml` lists all 5 canonical URLs.
- Retries each route up to 30 × 10s (matches existing deploy poll cadence) before failing — App Runner needs a warm-up window.
- Uses `common.sh` helpers (`section`, `info`, `warn`, `die`, `http_status`).

### 3.2 `rollback.sh`

**Contract:** restore the previously-deployed image and verify.

```bash
deployment/bin/rollback.sh [--to <image-digest>] [--service-arn <arn>]
```

- If `--to` omitted, reads `deployment/.last-good-digest` (written by the deploy job before each successful deploy).
- `docker pull` the digest from ECR → retag as `:latest` → `docker push` → `aws apprunner start-deployment` → poll → smoke-test.
- Refuses to run if the "previous" digest equals the currently-deploying one (no-op guard).
- Exit codes: `0` restored, `1` rollback failed (page a human), `2` nothing to roll back to.

### 3.3 Preview scripts

`preview-create.sh <pr-number> <image-tag>`:
- `aws apprunner create-service --service-name portfolio-pr-<N>` sourcing `:pr-<N>` from ECR.
- Sets `ROBOTS_NOINDEX=1` env var (see §4 for the Flask gate).
- Sets `SITE_URL=https://<apprunner-default-url>` so canonical tags and sitemap reflect the preview host.
- Emits the default App Runner URL to stdout for the workflow to capture.
- Idempotent: if service exists, returns the existing URL.

`preview-destroy.sh <pr-number>`:
- `aws apprunner delete-service` for `portfolio-pr-<N>`. Tolerant of already-deleted state.

### 3.4 `deploy.yml` extensions

New steps added to the existing `deploy` job, in order:

1. **Capture previous digest** (before `start-deployment`):
   ```
   aws apprunner describe-service --service-arn $ARN
     --query 'Service.SourceConfiguration.ImageRepository.ImageIdentifier'
   ```
   Write to job output `previous_digest`.
2. **Existing deploy + health poll** (unchanged).
3. **Smoke test:** `deployment/bin/smoke-test.sh $DEPLOY_HEALTHCHECK_URL` (URL minus `/health`).
4. **Rollback on failure:** if step 3 fails, invoke `rollback.sh --to $previous_digest`; then `exit 1` to mark the workflow failed so the human gets alerted *after* prod is restored.
5. **Persist last-good:** on success, write `$deployed_digest` to the `deployment/.last-good-digest` artifact uploaded for the next run (or, simpler: rely on `describe-service` each time — no artifact needed).

### 3.5 `pr-preview.yml` (new workflow)

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, closed]
```

Jobs:
- `build-preview` (opened/synchronize/reopened): reuse the existing `build` + `push-ecr` logic with `IMAGE_TAG=pr-${{ github.event.number }}`; then call `preview-create.sh`; then `smoke-test.sh` against the returned URL; then `gh pr comment` with the URL.
- `teardown-preview` (closed): call `preview-destroy.sh ${{ github.event.number }}`.
- Concurrency key: `preview-${{ github.event.number }}` with `cancel-in-progress: true`.

Required new GitHub repo variables: none. Reuses `AWS_ROLE_TO_ASSUME`, `AWS_REGION`, `ECR_REPOSITORY`. IAM policy gets two additions: `apprunner:CreateService`, `apprunner:DeleteService` (scope to services matching `portfolio-pr-*` via a resource condition).

### 3.6 `Makefile` additions

```makefile
ship:               ## deploy-check → push branch → open PR to main
	@make deploy-check
	@git push -u origin HEAD
	@gh pr create --fill --base main

smoke-test:         ## smoke-test prod (override URL=...)
	@deployment/bin/smoke-test.sh $${URL:-https://rickarko.com}

rollback:           ## restore the previous good image to prod
	@deployment/bin/rollback.sh

preview-create:     ## manual preview spin-up for current PR
	@deployment/bin/preview-create.sh $$(gh pr view --json number -q .number) pr-$$(gh pr view --json number -q .number)

preview-destroy:    ## manual preview teardown for current PR
	@deployment/bin/preview-destroy.sh $$(gh pr view --json number -q .number)
```

---

## 4. Code changes outside `deployment/`

### 4.1 `factory.py` — robots gate for previews

Previews must never be indexed. Add a settings-driven override:

- `Settings.robots_noindex: bool` (default `False`), sourced from `ROBOTS_NOINDEX` env var.
- In `seo.build_page`, if `settings.robots_noindex`, force `robots="noindex,nofollow"` for all pages.
- In `factory.robots()`, if `settings.robots_noindex`, emit `User-agent: *\nDisallow: /` and omit the sitemap line.

Matching unit test in `tests/unit/test_seo.py`: `test_robots_noindex_override_forces_noindex_on_all_pages`.

### 4.2 Smoke-test parity regression

`tests/regression/test_smoke_contract.py`:
- Parses `deployment/bin/smoke-test.sh` for the per-route snippet table.
- Asserts it equals `HTML_PAGES` in `test_routes.py`.
- Prevents drift between the Python e2e contract and the bash smoke-test contract.

---

## 5. IAM / security deltas

Add to `deployment/aws/github-actions-deploy-policy.json`:

- `AppRunnerPreview` statement:
  - Actions: `apprunner:CreateService`, `apprunner:DeleteService`, `apprunner:DescribeService`, `apprunner:ListOperations`, `apprunner:TagResource`
  - Resource: `arn:aws:apprunner:us-east-1:<ACCT>:service/portfolio-pr-*/*`
- Existing `AppRunnerDeploy` statement unchanged (prod service only).

No change to the OIDC trust policy — preview workflow still runs on PRs from the same repo, ref is `refs/pull/<n>/merge`; the trust policy currently pins to `refs/heads/main`, so extend the `sub` condition to also allow `repo:RickArko/RickArkoPortfolio:pull_request`.

**Risk to flag:** allowing pull_request triggers to assume a role that can create App Runner services means a malicious PR from a fork could spin infra. Mitigation: restrict `pr-preview.yml` to `if: github.event.pull_request.head.repo.full_name == github.repository` (same-repo PRs only). Document this in the workflow.

---

## 6. Non-goals (explicit)

- ❌ `develop` branch or `dev.rickarko.com`. Adds cost and complexity without proportional safety gain for a JSON-content site.
- ❌ Blue/green or canary. No DB, no stateful migrations; App Runner's own rolling deploy + our rollback is sufficient.
- ❌ Terraform / CDK migration. Bash scripts in `deployment/bin/` are idempotent and readable; rewriting to look serious is a negative signal.
- ❌ Browser-based e2e (Playwright/Cypress). The HTTP-first contract tests already cover the rendered surface.

---

## 7. Rollout order (half-day of focused work)

1. **`smoke-test.sh` + parity test** — risk-free, testable locally against prod.
2. **Digest capture + smoke-test step in `deploy.yml`** — still no rollback; just fail-loud if prod regressed.
3. **`rollback.sh` + wire into `deploy.yml`** — now prod self-heals.
4. **`factory.py` robots gate + unit test** — needed before previews can exist publicly.
5. **Preview scripts + `pr-preview.yml`** — the new capability.
6. **`make ship` + `DEPLOY.md` update** — ergonomics and docs.

Each step is independently shippable via its own PR, which itself exercises the preview flow once step 5 lands.

---

## 8. Acceptance criteria

- `make ship` from any feature branch opens a PR, triggers a preview, and posts its URL within ~5 min.
- Merging to `main` deploys, smoke-tests, and — on smoke failure — restores the previous digest automatically; the workflow surfaces a red X and a linked rollback log.
- `make rollback` from a laptop restores prod in under 3 minutes given only AWS creds and the repo checkout.
- Preview services cost $0 when no PRs are open (verified via `aws apprunner list-services | grep portfolio-pr-` being empty).
- The smoke-test contract and `HTML_PAGES` cannot drift silently (regression test enforces).

---

## 9. Runbook: prod regression

1. CI is red after a merge → check the workflow's `smoke-test` step output.
2. If `rollback.sh` already ran, prod is on the previous digest. Verify with `make smoke-test`.
3. Open a revert PR for the offending commit; let the normal pipeline re-deploy.
4. If rollback itself failed (exit 1): `make rollback --to <known-good-digest>` from a laptop, or retag manually via `deployment/bin/ecr-setup.sh --skip-build` after pulling the good digest.
5. Post-incident: write a short note in the PR that caused the regression — what the smoke test caught, what the e2e suite missed, and which new assertion closes the gap.
