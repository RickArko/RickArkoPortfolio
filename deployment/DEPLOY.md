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
make test
make docker-build
```

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
