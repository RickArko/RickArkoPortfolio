#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

require_cmd aws
require_cmd docker

SERVICE_ARN="$(lookup_service_arn "$SERVICE_NAME" "$AWS_REGION" || true)"
[[ -n "$SERVICE_ARN" ]] || die "Could not find an App Runner service named '$SERVICE_NAME'."

APP_NAME="$REPO_NAME" \
AWS_REGION="$AWS_REGION" \
LOCAL_IMAGE="$LOCAL_IMAGE" \
IMAGE_TAG="$ECR_IMAGE_TAG" \
"$REPO_ROOT/deployment/bin/ecr-setup.sh"

section "Update"
printf "Service: %s\nService ARN: %s\n\n" "$SERVICE_NAME" "$SERVICE_ARN"

aws apprunner start-deployment --service-arn "$SERVICE_ARN" --region "$AWS_REGION" >/dev/null
info "Deployment started."
