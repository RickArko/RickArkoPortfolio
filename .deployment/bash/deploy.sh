#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

require_cmd aws
require_cmd docker

section "Deploy"
printf "Repo: %s\nService: %s\nRegion: %s\nImage: %s\n\n" \
    "$REPO_NAME" "$SERVICE_NAME" "$AWS_REGION" "$ECR_IMAGE"

APP_NAME="$REPO_NAME" \
AWS_REGION="$AWS_REGION" \
LOCAL_IMAGE="$LOCAL_IMAGE" \
IMAGE_TAG="$ECR_IMAGE_TAG" \
"$REPO_ROOT/deployment/bin/ecr-setup.sh"

SERVICE_ARN="$(lookup_service_arn "$SERVICE_NAME" "$AWS_REGION" || true)"

if [[ -n "$SERVICE_ARN" ]]; then
    warn "Service already exists. Starting a fresh deployment instead of creating a new one."
    aws apprunner start-deployment --service-arn "$SERVICE_ARN" --region "$AWS_REGION" >/dev/null
    info "Deployment started for $SERVICE_NAME"
    exit 0
fi

info "Creating App Runner service: $SERVICE_NAME"
aws apprunner create-service \
    --service-name "$SERVICE_NAME" \
    --source-configuration "{
      \"ImageRepository\": {
        \"ImageIdentifier\": \"${ECR_IMAGE}\",
        \"ImageRepositoryType\": \"ECR\",
        \"ImageConfiguration\": {
          \"Port\": \"8080\"
        }
      },
      \"AutoDeploymentsEnabled\": true
    }" \
    --instance-configuration "{
      \"Cpu\": \"${CPU}\",
      \"Memory\": \"${MEMORY}\"
    }" \
    --health-check-configuration '{
      "Protocol": "HTTP",
      "Path": "/health",
      "Interval": 10,
      "Timeout": 5,
      "HealthyThreshold": 1,
      "UnhealthyThreshold": 5
    }' \
    --region "$AWS_REGION" >/dev/null

info "App Runner service created."
