# Deployment Runbook

Primary target: **AWS App Runner** with **ECR** as the image source and **Route 53** for DNS.

This document is the source of truth for how to ship changes safely.
If you follow only one path, follow the "Golden Path" in the next section.

## Golden Path

For normal day-to-day releases:

1. run local preflight from WSL:
   - `make deploy-check`
2. push your branch and open a pull request
3. let GitHub Actions run the fast quality gate
4. merge to `main`
5. let GitHub Actions run:
   - `make verify`
   - Docker build
   - ECR publish
   - App Runner deployment
   - health verification against `https://rickarko.com/health`
6. confirm:
   - GitHub Actions deploy job is green
   - `https://rickarko.com/health` returns `application/json`
   - body is `{"status":"ok"}`

Manual terminal deployment should be treated as the fallback path for emergencies,
maintenance windows, or pipeline debugging.

## Linux-first tooling

Use:

- `make`
- `deployment/bin/*.sh`
- WSL if you are on Windows

Do not add new PowerShell automation. Old scripts are archived in `deployment/windows/legacy/`.

## Prerequisites

```bash
aws --version
docker --version
uv --version
```

Recommended extras:

```bash
make help
shellcheck --version
```

## Important variables

These can be passed through the environment when needed:

```bash
APP_NAME=rickarko_portfolio
SERVICE_NAME=RickArko_Portfolio
AWS_REGION=us-east-1
DOMAIN=rickarko.com
```

Current production assumptions:

- App Runner service name: `RickArko_Portfolio`
- ECR repository used by the live service: `rickarko_portfolio`
- health contract: `GET /health` returns JSON `{"status":"ok"}`

## Local verification

```bash
make install
make verify
make doctor-aws
make deploy-check
make docker-build
```

`make doctor-aws` validates your local AWS CLI identity plus ECR/App Runner/domain wiring.

`make deploy-check` is a stricter no-push preflight: it runs the fast local quality gate, checks Docker availability, runs the AWS doctor, and performs a local Docker build.

Expected outcome:

- Python quality gate passes
- Docker build succeeds
- AWS identity resolves
- ECR repository exists
- App Runner service exists and is queryable
- custom domain is associated
- both service and custom-domain `/health` endpoints respond

## One-Time Setup Checklist

Before relying on CI/CD, make sure these are true:

1. AWS infrastructure exists:
   - ECR repository `rickarko_portfolio`
   - App Runner service `RickArko_Portfolio`
   - Route 53 hosted zone for `rickarko.com`
2. App Runner is configured to pull from:
   - `122610507380.dkr.ecr.us-east-1.amazonaws.com/rickarko_portfolio:latest`
3. GitHub OIDC is configured:
   - GitHub OIDC provider exists in IAM
   - deploy role trust policy allows this repository on `main`
   - deploy role policy grants ECR push plus App Runner deploy permissions
4. GitHub repository variables are set:
   - `AWS_ROLE_TO_ASSUME`
   - `AWS_REGION`
   - `ECR_REPOSITORY`
   - `APPRUNNER_SERVICE_ARN`
5. Branch protection is enabled on `main`
6. The GitHub Actions deploy workflow has completed successfully at least once

## GitHub Actions CI/CD pipeline

The repository ships with an end-to-end GitHub Actions pipeline in
`.github/workflows/deploy.yml`.

### Pipeline stages

1. `Fast Quality Gate`
   - runs on every pull request and push
   - executes `make check`
   - catches lint, formatting, and fast pytest failures early
2. `Full Verification`
   - runs on pushes to `main` and manual `workflow_dispatch`
   - installs `shellcheck`
   - executes `make verify`
   - blocks release work if tests, coverage, or shell checks fail
3. `Build Release Image`
   - builds the Docker image
   - tags it with the commit SHA and `latest`
   - stores the image as a short-lived workflow artifact
4. `Publish To ECR`
   - authenticates to AWS
   - pushes the SHA-tagged and `latest` images to ECR
5. `Deploy To App Runner`
   - triggers `aws apprunner start-deployment`
   - waits for the App Runner deployment operation to settle
   - performs a post-deploy health check against `https://rickarko.com/health`
   - validates that the endpoint returns the JSON health contract, not just an HTTP `200`

### Required GitHub repository variables

OIDC removes the need for long-lived AWS access keys in GitHub.

Use GitHub repository variables instead:

- `AWS_ROLE_TO_ASSUME`
- `AWS_REGION`
- `ECR_REPOSITORY`
- `APPRUNNER_SERVICE_ARN`

Recommended values:

- `AWS_REGION=us-east-1`
- `ECR_REPOSITORY=rickarko_portfolio`

### AWS OIDC setup

The workflow now assumes an IAM role via GitHub OIDC instead of using
`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.

1. Create or confirm the AWS IAM OIDC identity provider for GitHub:
   - provider URL: `https://token.actions.githubusercontent.com`
   - audience: `sts.amazonaws.com`
2. Create an IAM role for GitHub Actions.
3. Use [deployment/aws/github-actions-oidc-trust-policy.json](/home/ricka/Git/RickArkoPortfolio/deployment/aws/github-actions-oidc-trust-policy.json) as the trust policy template.
4. Attach [deployment/aws/github-actions-deploy-policy.json](/home/ricka/Git/RickArkoPortfolio/deployment/aws/github-actions-deploy-policy.json) after replacing the placeholders with your real account, region, repository, and App Runner service ARN.
5. Add the following GitHub repository variables:
   - `AWS_ROLE_TO_ASSUME`
   - `AWS_REGION`
   - `ECR_REPOSITORY`
   - `APPRUNNER_SERVICE_ARN`
6. Remove any old long-lived AWS secrets from GitHub Actions once OIDC is working.

The trust policy intentionally restricts role assumption to the `main` branch.
That matches the workflow, which only publishes and deploys from `refs/heads/main`.

### Recommended repository settings

- protect `main`
- require the GitHub Actions quality gate before merge
- use `workflow_dispatch` for manual redeploys when needed
- keep App Runner pointed at the ECR repository managed by the workflow
- prefer GitHub OIDC over stored AWS access keys
- require the GitHub Actions deploy workflow before production changes are considered complete

## Daily Release Workflows

### CI/CD release

This is the preferred path.

```bash
make deploy-check
git push
```

Then:

1. open a pull request
2. wait for `Fast Quality Gate`
3. merge to `main`
4. watch the `Portfolio CI/CD` workflow
5. confirm the deploy stage succeeds

### Manual terminal release

Use this for emergency releases or when debugging the pipeline.

```bash
make deploy-check
make ecr-setup
aws apprunner start-deployment --service-arn "$APPRUNNER_SERVICE_ARN" --region "$AWS_REGION"
```

Watch the rollout:

```bash
watch -n 5 "aws apprunner list-operations \
  --service-arn \"$APPRUNNER_SERVICE_ARN\" \
  --region \"$AWS_REGION\" \
  --query 'OperationSummaryList[0].[Status,Type]' \
  --output table"
```

Verify the service once the operation becomes `SUCCEEDED`:

```bash
curl -i "https://ctydyem9cj.us-east-1.awsapprunner.com/health"
curl -i "https://rickarko.com/health"
```

Healthy output must satisfy all of these:

- HTTP status is `200`
- `content-type` begins with `application/json`
- body contains `{"status":"ok"}`

An HTML `200` response is a failed health contract, even if the site appears reachable.

## First deploy

### 1. Push the image to ECR

```bash
make ecr-setup
```

This uses `deployment/bin/ecr-setup.sh` and will:

- create the ECR repository if needed
- log Docker into ECR
- build the image
- tag it
- push it

### 2. Create or update the App Runner service

If the service does not exist yet, create it with the AWS CLI or console using `apprunner.yaml` and the pushed ECR image.

If it already exists and auto-deploy is off:

```bash
aws apprunner start-deployment --service-arn "$APPRUNNER_SERVICE_ARN"
```

### 3. Associate the custom domain

```bash
make domain-setup
```

This uses `deployment/bin/apprunner-domain-setup.sh` and will:

- find the App Runner service
- associate the custom domain
- create or reuse the Route 53 hosted zone
- upsert certificate validation CNAMEs
- upsert the apex alias record
- optionally upsert `www`

### 4. Inspect status

```bash
make domain-status
make domain-debug
```

## Runtime Verification

Use these commands after a release:

```bash
aws apprunner describe-service \
  --service-arn "$APPRUNNER_SERVICE_ARN" \
  --region "$AWS_REGION" \
  --query "Service.{Status:Status,Url:ServiceUrl,Image:SourceConfiguration.ImageRepository.ImageIdentifier}" \
  --output table

aws apprunner list-operations \
  --service-arn "$APPRUNNER_SERVICE_ARN" \
  --region "$AWS_REGION" \
  --max-results 5
```

Use these commands to validate user-visible behavior:

```bash
curl -i https://rickarko.com/health
curl -i https://ctydyem9cj.us-east-1.awsapprunner.com/health
curl -I https://rickarko.com
```

If App Runner says the service is healthy but `/health` returns HTML instead of JSON,
treat that as a failed rollout.

## Manual script usage

```bash
./deployment/bin/ecr-setup.sh
./deployment/bin/apprunner-domain-setup.sh
./deployment/bin/apprunner-domain-status.sh --detailed
./deployment/bin/apprunner-debug.sh --watch
```

## Health checks

```bash
curl -i https://rickarko.com/health
curl -i https://ctydyem9cj.us-east-1.awsapprunner.com/health
curl -I https://rickarko.com
```

Expected health response:

```http
HTTP/1.1 200 OK
content-type: application/json

{"status":"ok"}
```

## Rollback

```bash
aws apprunner list-operations --service-arn "$APPRUNNER_SERVICE_ARN"
aws apprunner start-deployment --service-arn "$APPRUNNER_SERVICE_ARN"
```

If you need to roll back the image itself, push a known-good tag back to `latest` and redeploy.

Recommended safer rollback pattern:

1. identify the last known-good image digest or tag in ECR
2. re-tag it as `latest`
3. trigger `aws apprunner start-deployment`
4. verify `/health` returns the JSON contract

## Troubleshooting

### `/health` returns HTML with status `200`

This means the old app revision is still serving traffic or the wrong container image is running.

Check:

```bash
aws apprunner describe-service \
  --service-arn "$APPRUNNER_SERVICE_ARN" \
  --region "$AWS_REGION" \
  --query "Service.SourceConfiguration.ImageRepository.ImageIdentifier" \
  --output text
```

Make sure it points at `rickarko_portfolio:latest`.

### `StartDeployment` says the service is not in `RUNNING` state

Another App Runner operation is already in progress.

Wait for the current operation to finish:

```bash
watch -n 5 "aws apprunner list-operations \
  --service-arn \"$APPRUNNER_SERVICE_ARN\" \
  --region \"$AWS_REGION\" \
  --query 'OperationSummaryList[0].[Status,Type]' \
  --output table"
```

### The old website is still live after an image push

Pushing to ECR is not enough if:

- App Runner auto-deploy is disabled
- or you pushed to the wrong ECR repository

Verify:

1. the ECR repo is `rickarko_portfolio`
2. App Runner is configured to read from that same repo
3. a deploy operation was actually triggered

### `doctor-aws` says the ECR repository is missing

That can mean one of two things:

- the repository truly does not exist
- or the active AWS identity lacks `ecr:DescribeRepositories`

If you suspect permissions, test with:

```bash
aws sts get-caller-identity
```

and compare against the IAM user or role you expect.

### Local image works, App Runner still serves the old app

That usually means the rollout has not completed yet, or App Runner is still pinned to an older ECR image source.

Confirm both:

```bash
docker run --rm -p 18080:8080 rickarko_portfolio:latest
curl -i http://127.0.0.1:18080/health
```

and:

```bash
aws apprunner describe-service \
  --service-arn "$APPRUNNER_SERVICE_ARN" \
  --region "$AWS_REGION"
```

## CI/CD Maturity Roadmap

The current pipeline is good enough for production, but this is the next maturity ladder:

1. enforce branch protection with required status checks
2. keep OIDC as the only CI/CD AWS auth path
3. require immutable SHA-tag deploy visibility in step summaries
4. add a GitHub `production` environment with manual approval for high-risk releases
5. switch App Runner health checks to HTTP `/health` instead of a generic TCP probe
6. add log aggregation, metrics, and alerting for failed deployments
7. add a rollback playbook that re-tags a known-good SHA automatically
8. eventually manage the App Runner service itself with IaC so the live service cannot drift from repo defaults

## Deployment flow summary

For day-to-day work, the intended end-to-end path is:

1. Open a pull request and let GitHub Actions run `make check`
2. Merge to `main` after the fast quality gate passes
3. Let GitHub Actions run `make verify`, build the Docker image, push it to ECR, and trigger App Runner deployment
4. Confirm the post-deploy `/health` check succeeds
5. Inspect `make domain-status` or the App Runner console only if something looks off
