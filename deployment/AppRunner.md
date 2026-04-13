# AWS App Runner Notes

## Current service

- **Service:** `RickArko_Portfolio`
- **Region:** `us-east-1`
- **Runtime:** Docker
- **Port:** `8080`
- **Public URL:** `https://ctydyem9cj.us-east-1.awsapprunner.com`
- **Custom domain:** `https://rickarko.com`
- **ECR repository:** `rickarko_portfolio`
- **Expected health contract:** `GET /health` -> `{"status":"ok"}`

## Typical release flow

```bash
make deploy-check
make ecr-setup
aws apprunner start-deployment --service-arn "$APPRUNNER_SERVICE_ARN" --region us-east-1
```

Then watch the rollout:

```bash
watch -n 5 "aws apprunner list-operations \
  --service-arn \"$APPRUNNER_SERVICE_ARN\" \
  --region us-east-1 \
  --query 'OperationSummaryList[0].[Status,Type]' \
  --output table"
```

## Verify the service

Infrastructure-level verification:

```bash
aws apprunner describe-service \
  --service-arn "$APPRUNNER_SERVICE_ARN" \
  --region us-east-1 \
  --query "Service.{Status:Status,Url:ServiceUrl,Image:SourceConfiguration.ImageRepository.ImageIdentifier,Updated:UpdatedAt}" \
  --output table

aws apprunner list-operations \
  --service-arn "$APPRUNNER_SERVICE_ARN" \
  --region us-east-1 \
  --max-results 5
```

Application-level verification:

```bash
curl -i https://ctydyem9cj.us-east-1.awsapprunner.com/health
curl -i https://rickarko.com/health
```

Healthy output means:

- operation status is `SUCCEEDED`
- service status is `RUNNING`
- the image identifier points at `rickarko_portfolio:latest`
- `/health` returns `application/json`
- body contains `{"status":"ok"}`

If `/health` returns HTML with `200 OK`, the old revision is still serving traffic or the wrong image source is configured.

## Create the service from scratch

If the service does not exist yet, use the AWS console or the CLI with the ECR image produced by `make ecr-setup`.

The application contract is:

- container port `8080`
- health endpoint `/health`
- production entrypoint via gunicorn
- ECR source image `rickarko_portfolio:latest`

`apprunner.yaml` remains the repo-level source of truth for the App Runner app definition.

## Recommended production settings

To keep App Runner aligned with the application contract:

- point the service at `rickarko_portfolio:latest`
- keep the service publicly accessible
- configure health checks to use HTTP `/health` rather than a generic TCP probe
- prefer the GitHub Actions OIDC deploy pipeline for normal releases
