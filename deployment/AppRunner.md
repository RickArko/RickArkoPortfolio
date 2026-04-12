# AWS App Runner Notes

## Current service

- **Service:** `RickArko_Portfolio`
- **Region:** `us-east-1`
- **Runtime:** Docker
- **Port:** `8080`
- **Public URL:** `https://ctydyem9cj.us-east-1.awsapprunner.com`
- **Custom domain:** `https://rickarko.com`

## Typical release flow

```bash
make test
make docker-build
make ecr-setup
aws apprunner start-deployment --service-arn "$APPRUNNER_SERVICE_ARN"
make domain-status
```

## Verify the service

```bash
aws apprunner describe-service \
  --service-arn "$APPRUNNER_SERVICE_ARN" \
  --query "Service.{Status:Status,Url:ServiceUrl,Updated:UpdatedAt}" \
  --output table

curl -s -o /dev/null -w "%{http_code}\n" https://ctydyem9cj.us-east-1.awsapprunner.com
curl -s -o /dev/null -w "%{http_code}\n" https://rickarko.com
```

## Create the service from scratch

If the service does not exist yet, use the AWS console or the CLI with the ECR image produced by `make ecr-setup`.

The application contract is:

- container port `8080`
- health endpoint `/health`
- production entrypoint via gunicorn

`apprunner.yaml` remains the repo-level source of truth for the App Runner app definition.
