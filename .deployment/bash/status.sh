#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

require_cmd aws

section "Status"
printf "Repo: %s\nService: %s\nRegion: %s\n\n" "$REPO_NAME" "$SERVICE_NAME" "$AWS_REGION"

SERVICE_ARN="$(lookup_service_arn "$SERVICE_NAME" "$AWS_REGION" || true)"

if [[ -n "$SERVICE_ARN" ]]; then
    printf "App Runner service:\n"
    aws apprunner describe-service \
        --service-arn "$SERVICE_ARN" \
        --region "$AWS_REGION" \
        --query "Service.{Name:ServiceName,Status:Status,Url:ServiceUrl,Updated:UpdatedAt}" \
        --output table
else
    warn "App Runner service not found."
fi

printf "\nECR repository:\n"
if aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    aws ecr describe-repositories \
        --repository-names "$REPO_NAME" \
        --region "$AWS_REGION" \
        --query "repositories[0].{Uri:repositoryUri,Created:createdAt}" \
        --output table
else
    warn "ECR repository not found."
fi
