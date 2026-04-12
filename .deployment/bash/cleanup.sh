#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

require_cmd aws

section "Cleanup"
printf "Repo: %s\nService: %s\nRegion: %s\n\n" "$REPO_NAME" "$SERVICE_NAME" "$AWS_REGION"
warn "This will delete the App Runner service and force-delete the ECR repository."
read -r -p "Type DELETE to continue: " confirmation

if [[ "$confirmation" != "DELETE" ]]; then
    warn "Cleanup cancelled."
    exit 0
fi

SERVICE_ARN="$(lookup_service_arn "$SERVICE_NAME" "$AWS_REGION" || true)"
if [[ -n "$SERVICE_ARN" ]]; then
    aws apprunner delete-service --service-arn "$SERVICE_ARN" --region "$AWS_REGION" >/dev/null || true
    info "App Runner service deletion requested."
else
    warn "No App Runner service found."
fi

if aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    aws ecr delete-repository --repository-name "$REPO_NAME" --region "$AWS_REGION" --force >/dev/null
    info "ECR repository deleted."
else
    warn "No ECR repository found."
fi
