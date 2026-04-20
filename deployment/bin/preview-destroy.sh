#!/usr/bin/env bash
# Delete the ephemeral preview App Runner service for a pull request.
#
# Usage: preview-destroy.sh <pr-number>
#
# Tolerant of already-deleted or never-created state. Always exits 0 unless
# an API error occurs; "service not found" is not an error.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

PR_NUMBER="${1:-}"
AWS_REGION="${AWS_REGION:-$AWS_REGION_DEFAULT}"

if [[ -z "$PR_NUMBER" ]]; then
    error "Usage: preview-destroy.sh <pr-number>"
    exit 2
fi

require_cmd aws

readonly SERVICE_NAME="portfolio-pr-${PR_NUMBER}"

section "Preview destroy: $SERVICE_NAME"

service_arn="$(
    aws apprunner list-services \
        --region "$AWS_REGION" \
        --query "ServiceSummaryList[?ServiceName=='${SERVICE_NAME}'] | [0].ServiceArn" \
        --output text 2>/dev/null || true
)"

if [[ -z "$service_arn" || "$service_arn" == "None" ]]; then
    info "No preview service to delete (already gone)."
    exit 0
fi

info "Deleting $service_arn"
aws apprunner delete-service \
    --service-arn "$service_arn" \
    --region "$AWS_REGION" >/dev/null

info "Delete requested. App Runner will reclaim resources asynchronously."
