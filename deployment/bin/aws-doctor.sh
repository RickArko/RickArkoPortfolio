#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

APP_NAME="${APP_NAME:-$APP_NAME_DEFAULT}"
SERVICE_NAME="${SERVICE_NAME:-$SERVICE_NAME_DEFAULT}"
SERVICE_ARN="${SERVICE_ARN:-}"
AWS_REGION="${AWS_REGION:-$AWS_REGION_DEFAULT}"
DOMAIN="${DOMAIN:-$DOMAIN_DEFAULT}"

show_help() {
    cat <<'EOF'
Usage: ./deployment/bin/aws-doctor.sh [options]

Validate local AWS deployment prerequisites without changing cloud resources.

Options:
  --app-name <name>         ECR repository name (default: rickarko_portfolio)
  --service-name <name>     App Runner service name (default: RickArko_Portfolio)
  --service-arn <arn>       App Runner service ARN (optional)
  --region <region>         AWS region (default: us-east-1)
  --domain <domain>         Public domain for health checks (default: rickarko.com)
  --help, -h                Show this help text
EOF
}

while (($#)); do
    case "$1" in
        --app-name)
            APP_NAME="$2"
            shift
            ;;
        --service-name)
            SERVICE_NAME="$2"
            shift
            ;;
        --service-arn)
            SERVICE_ARN="$2"
            shift
            ;;
        --region)
            AWS_REGION="$2"
            shift
            ;;
        --domain)
            DOMAIN="$2"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            die "Unknown argument: $1"
            ;;
    esac
    shift
done

require_cmd aws

if ! command -v curl >/dev/null 2>&1; then
    warn "curl not installed; HTTP checks will be skipped."
fi

section "AWS identity"
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query 'Account' --output text)"
AWS_ARN="$(aws sts get-caller-identity --query 'Arn' --output text)"
printf "Account: %s\nARN: %s\nRegion: %s\n\n" "$AWS_ACCOUNT_ID" "$AWS_ARN" "$AWS_REGION"

section "ECR repository"
ecr_error_file="$(mktemp)"
if aws ecr describe-repositories --repository-names "$APP_NAME" --region "$AWS_REGION" >/dev/null 2>"$ecr_error_file"; then
    rm -f "$ecr_error_file"
    info "ECR repository exists: $APP_NAME"
else
    ecr_error="$(<"$ecr_error_file")"
    rm -f "$ecr_error_file"

    if [[ "$ecr_error" == *"AccessDenied"* || "$ecr_error" == *"not authorized"* ]]; then
        die "Cannot inspect ECR repository '$APP_NAME'. The active AWS identity lacks ecr:DescribeRepositories permissions."
    fi

    die "ECR repository not found: $APP_NAME"
fi

section "App Runner service"
if [[ -z "$SERVICE_ARN" ]]; then
    SERVICE_ARN="$(lookup_service_arn "$SERVICE_NAME" "$AWS_REGION" || true)"
fi
[[ -n "$SERVICE_ARN" ]] || die "Could not find an App Runner service named '$SERVICE_NAME'."

SERVICE_STATUS="$(
    aws apprunner describe-service \
        --service-arn "$SERVICE_ARN" \
        --region "$AWS_REGION" \
        --query 'Service.Status' \
        --output text
)"
SERVICE_URL="$(describe_service_url "$SERVICE_ARN" "$AWS_REGION")"
printf "Service: %s\nARN: %s\nStatus: %s\nURL: https://%s\n\n" \
    "$SERVICE_NAME" "$SERVICE_ARN" "$SERVICE_STATUS" "$SERVICE_URL"

section "Deployment wiring"
if lookup_hosted_zone_id "$DOMAIN" >/dev/null 2>&1; then
    info "Route 53 hosted zone exists for $DOMAIN"
else
    warn "No Route 53 hosted zone found for $DOMAIN"
fi

DOMAIN_STATUS="$(describe_domain_status "$SERVICE_ARN" "$AWS_REGION" "$DOMAIN" || true)"
if [[ -n "$DOMAIN_STATUS" && "$DOMAIN_STATUS" != "None" ]]; then
    printf "Custom domain status: %s\n" "$DOMAIN_STATUS"
else
    warn "No App Runner custom-domain record found for $DOMAIN"
fi

if command -v curl >/dev/null 2>&1; then
    printf "Health endpoint (%s): %s\n" "https://$DOMAIN/health" "$(http_status "https://$DOMAIN/health")"
    printf "Service health (%s): %s\n" "https://$SERVICE_URL/health" "$(http_status "https://$SERVICE_URL/health")"
fi

info "AWS deployment doctor checks passed."
