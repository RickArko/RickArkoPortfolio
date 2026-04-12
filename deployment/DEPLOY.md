# Deployment Runbook

Primary target: **AWS App Runner** with **ECR** as the image source and **Route 53** for DNS.

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
APP_NAME=rickarkoportfolio
SERVICE_NAME=RickArko_Portfolio
AWS_REGION=us-east-1
DOMAIN=rickarko.com
```

## Local verification

```bash
make install
make verify
make docker-build
```

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

### Required GitHub repository variables

OIDC removes the need for long-lived AWS access keys in GitHub.

Use GitHub repository variables instead:

- `AWS_ROLE_TO_ASSUME`
- `AWS_REGION`
- `ECR_REPOSITORY`
- `APPRUNNER_SERVICE_ARN`

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

## Manual script usage

```bash
./deployment/bin/ecr-setup.sh
./deployment/bin/apprunner-domain-setup.sh
./deployment/bin/apprunner-domain-status.sh --detailed
./deployment/bin/apprunner-debug.sh --watch
```

## Health checks

```bash
curl -sf https://rickarko.com/health && echo OK
curl -I https://rickarko.com
```

## Rollback

```bash
aws apprunner list-operations --service-arn "$APPRUNNER_SERVICE_ARN"
aws apprunner start-deployment --service-arn "$APPRUNNER_SERVICE_ARN"
```

If you need to roll back the image itself, push a known-good tag back to `latest` and redeploy.

## Deployment flow summary

For day-to-day work, the intended end-to-end path is:

1. Open a pull request and let GitHub Actions run `make check`
2. Merge to `main` after the fast quality gate passes
3. Let GitHub Actions run `make verify`, build the Docker image, push it to ECR, and trigger App Runner deployment
4. Confirm the post-deploy `/health` check succeeds
5. Inspect `make domain-status` or the App Runner console only if something looks off
