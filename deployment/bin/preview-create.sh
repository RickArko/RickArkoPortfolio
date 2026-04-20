#!/usr/bin/env bash
# Spin up an ephemeral App Runner service for a pull request.
#
# Usage: preview-create.sh <pr-number> <image-tag>
#
# Creates (or reuses) a service named `portfolio-pr-<N>` sourced from
# ECR_REPOSITORY:<image-tag>. Sets ROBOTS_NOINDEX=1 so search engines
# cannot index previews, and SITE_URL to the service's own default URL
# so canonical tags reflect the preview host.
#
# Idempotent: if the service already exists, prints its URL and returns 0.
# Prints only the preview URL to stdout on success; all logs go to stderr.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

PR_NUMBER="${1:-}"
IMAGE_TAG="${2:-}"
AWS_REGION="${AWS_REGION:-$AWS_REGION_DEFAULT}"
ECR_REPOSITORY="${ECR_REPOSITORY:-$APP_NAME_DEFAULT}"
APPRUNNER_ACCESS_ROLE_ARN="${APPRUNNER_ACCESS_ROLE_ARN:-}"

if [[ -z "$PR_NUMBER" || -z "$IMAGE_TAG" ]]; then
    error "Usage: preview-create.sh <pr-number> <image-tag>"
    exit 2
fi

if [[ -z "$APPRUNNER_ACCESS_ROLE_ARN" ]]; then
    error "APPRUNNER_ACCESS_ROLE_ARN must be set (IAM role App Runner uses to pull from ECR)."
    exit 2
fi

require_cmd aws

readonly SERVICE_NAME="portfolio-pr-${PR_NUMBER}"

# Log to stderr so the final URL stays the only thing on stdout.
log() { printf "%s\n" "$*" >&2; }

log "== Preview create =="
log "  service : $SERVICE_NAME"
log "  region  : $AWS_REGION"
log "  repo    : $ECR_REPOSITORY"
log "  tag     : $IMAGE_TAG"

# -----------------------------------------------------------------------------
# Idempotency: if service exists, return its URL
# -----------------------------------------------------------------------------
existing_arn="$(
    aws apprunner list-services \
        --region "$AWS_REGION" \
        --query "ServiceSummaryList[?ServiceName=='${SERVICE_NAME}'] | [0].ServiceArn" \
        --output text 2>/dev/null || true
)"

if [[ -n "$existing_arn" && "$existing_arn" != "None" ]]; then
    log "Service already exists — reusing: $existing_arn"
    url="$(describe_service_url "$existing_arn" "$AWS_REGION")"
    printf "https://%s\n" "$url"
    exit 0
fi

# -----------------------------------------------------------------------------
# Resolve the full ECR image URI
# -----------------------------------------------------------------------------
account_id="$(aws sts get-caller-identity --query 'Account' --output text)"
image_uri="${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"
log "  image   : $image_uri"

# -----------------------------------------------------------------------------
# Create the service
# -----------------------------------------------------------------------------
tmp_config="$(mktemp)"
trap 'rm -f "$tmp_config"' EXIT

cat > "$tmp_config" <<EOF
{
  "ImageRepository": {
    "ImageIdentifier": "${image_uri}",
    "ImageRepositoryType": "ECR",
    "ImageConfiguration": {
      "Port": "8080",
      "RuntimeEnvironmentVariables": {
        "FLASK_ENV": "production",
        "ROBOTS_NOINDEX": "1"
      }
    }
  },
  "AutoDeploymentsEnabled": false,
  "AuthenticationConfiguration": {
    "AccessRoleArn": "${APPRUNNER_ACCESS_ROLE_ARN}"
  }
}
EOF

log "Creating service..."
service_arn="$(
    aws apprunner create-service \
        --region "$AWS_REGION" \
        --service-name "$SERVICE_NAME" \
        --source-configuration "file://$tmp_config" \
        --instance-configuration '{"Cpu":"0.25 vCPU","Memory":"0.5 GB"}' \
        --tags "Key=Project,Value=rickarko-portfolio" "Key=Ephemeral,Value=true" "Key=PR,Value=${PR_NUMBER}" \
        --query 'Service.ServiceArn' \
        --output text
)"
log "  arn: $service_arn"

# -----------------------------------------------------------------------------
# Wait for the service to reach RUNNING
# -----------------------------------------------------------------------------
log "Waiting for service to reach RUNNING..."
for attempt in $(seq 1 60); do
    status="$(
        aws apprunner describe-service \
            --service-arn "$service_arn" \
            --region "$AWS_REGION" \
            --query 'Service.Status' \
            --output text
    )"
    case "$status" in
        RUNNING)
            log "  service is RUNNING (attempt $attempt)"
            break
            ;;
        CREATE_FAILED|DELETED|DELETE_FAILED)
            error "service entered terminal state: $status"
            exit 1
            ;;
        *)
            log "  attempt $attempt/60: status=$status; sleeping 10s"
            sleep 10
            ;;
    esac
done

url="$(describe_service_url "$service_arn" "$AWS_REGION")"
log "  url: https://${url}"

# Only the URL goes to stdout.
printf "https://%s\n" "$url"
