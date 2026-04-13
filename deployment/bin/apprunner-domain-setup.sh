#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

DOMAIN="${DOMAIN:-$DOMAIN_DEFAULT}"
SERVICE_NAME="${SERVICE_NAME:-$SERVICE_NAME_DEFAULT}"
SERVICE_ARN="${SERVICE_ARN:-}"
AWS_REGION="${AWS_REGION:-$AWS_REGION_DEFAULT}"
HOSTED_ZONE_ID="${HOSTED_ZONE_ID:-}"
APPRUNNER_HOSTED_ZONE_ID="${APPRUNNER_HOSTED_ZONE_ID:-$APPRUNNER_HOSTED_ZONE_ID_DEFAULT}"
ENABLE_WWW=1
SKIP_ROUTE53=0
SKIP_HOSTED_ZONE_CREATE=0

while (($#)); do
    case "$1" in
        --domain)
            DOMAIN="$2"
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
        --hosted-zone-id)
            HOSTED_ZONE_ID="$2"
            shift
            ;;
        --apprunner-hosted-zone-id)
            APPRUNNER_HOSTED_ZONE_ID="$2"
            shift
            ;;
        --no-www)
            ENABLE_WWW=0
            ;;
        --skip-route53)
            SKIP_ROUTE53=1
            ;;
        --skip-hosted-zone-create)
            SKIP_HOSTED_ZONE_CREATE=1
            ;;
        --help|-h)
            cat <<'EOF'
Usage: ./deployment/bin/apprunner-domain-setup.sh [options]

Options:
  --domain <domain>                     Custom domain name
  --service-name <name>                 App Runner service name
  --service-arn <arn>                   App Runner service ARN
  --region <region>                     AWS region
  --hosted-zone-id <zone-id>            Route 53 hosted zone ID
  --apprunner-hosted-zone-id <zone-id>  Route 53 alias zone ID for App Runner
  --no-www                              Do not manage a www CNAME
  --skip-route53                        Associate the custom domain but do not modify Route 53
  --skip-hosted-zone-create             Fail instead of creating a Route 53 hosted zone
EOF
            exit 0
            ;;
        *)
            die "Unknown argument: $1"
            ;;
    esac
    shift
done

require_cmd aws

if [[ -z "$SERVICE_ARN" ]]; then
    SERVICE_ARN="$(lookup_service_arn "$SERVICE_NAME" "$AWS_REGION" || true)"
fi
[[ -n "$SERVICE_ARN" ]] || die "Could not find an App Runner service named '$SERVICE_NAME'."

SERVICE_URL="$(describe_service_url "$SERVICE_ARN" "$AWS_REGION")"
[[ -n "$SERVICE_URL" && "$SERVICE_URL" != "None" ]] || die "Could not resolve the App Runner service URL."

if [[ "$SKIP_ROUTE53" -eq 0 ]]; then
    if [[ -z "$HOSTED_ZONE_ID" ]]; then
        HOSTED_ZONE_ID="$(lookup_hosted_zone_id "$DOMAIN" || true)"
    fi

    if [[ -z "$HOSTED_ZONE_ID" ]]; then
        if [[ "$SKIP_HOSTED_ZONE_CREATE" -eq 1 ]]; then
            die "Route 53 hosted zone for '$DOMAIN' was not found."
        fi
        warn "No hosted zone found for $DOMAIN. Creating one in Route 53."
        HOSTED_ZONE_ID="$(ensure_hosted_zone "$DOMAIN")"
    fi
fi

section "App Runner custom domain setup"
printf "Domain: %s\nService: %s\nRegion: %s\nService ARN: %s\nService URL: %s\n" \
    "$DOMAIN" "$SERVICE_NAME" "$AWS_REGION" "$SERVICE_ARN" "$SERVICE_URL"
if [[ -n "$HOSTED_ZONE_ID" ]]; then
    printf "Hosted zone: %s\n" "$HOSTED_ZONE_ID"
fi
printf "\n"

associate_command=(
    aws apprunner associate-custom-domain
    --service-arn "$SERVICE_ARN"
    --domain-name "$DOMAIN"
    --region "$AWS_REGION"
)

if [[ "$ENABLE_WWW" -eq 1 ]]; then
    associate_command+=(--enable-www-subdomain)
fi

if "${associate_command[@]}" >/dev/null 2>&1; then
    info "Custom domain association started."
else
    existing_domain="$(aws apprunner describe-custom-domains \
        --service-arn "$SERVICE_ARN" \
        --region "$AWS_REGION" \
        --query "CustomDomains[?DomainName=='${DOMAIN}'] | [0].DomainName" \
        --output text)"

    if [[ "$existing_domain" == "$DOMAIN" ]]; then
        warn "Domain is already associated with this service. Continuing."
    else
        die "Failed to associate $DOMAIN with App Runner."
    fi
fi

if [[ "$SKIP_ROUTE53" -eq 0 ]]; then
    change_batch_file="$(mktemp)"
    trap 'rm -f "$change_batch_file"' EXIT

    {
        printf '{"Changes":['
        separator=""

        while IFS=$'\t' read -r record_name record_value; do
            if [[ -z "${record_name:-}" || "$record_name" == "None" ]]; then
                continue
            fi

            printf '%s{"Action":"UPSERT","ResourceRecordSet":{"Name":"%s","Type":"CNAME","TTL":300,"ResourceRecords":[{"Value":"%s"}]}}' \
                "$separator" "$record_name" "$record_value"
            separator=","
        done < <(
            aws apprunner describe-custom-domains \
                --service-arn "$SERVICE_ARN" \
                --region "$AWS_REGION" \
                --query "CustomDomains[?DomainName=='${DOMAIN}'] | [0].CertificateValidationRecords[*].[Name,Value]" \
                --output text
        )

        printf '%s{"Action":"UPSERT","ResourceRecordSet":{"Name":"%s","Type":"A","AliasTarget":{"HostedZoneId":"%s","DNSName":"%s","EvaluateTargetHealth":false}}}' \
            "$separator" "$DOMAIN" "$APPRUNNER_HOSTED_ZONE_ID" "$SERVICE_URL"
        separator=","

        if [[ "$ENABLE_WWW" -eq 1 ]]; then
            printf '%s{"Action":"UPSERT","ResourceRecordSet":{"Name":"www.%s","Type":"CNAME","TTL":300,"ResourceRecords":[{"Value":"%s"}]}}' \
                "$separator" "$DOMAIN" "$SERVICE_URL"
        fi

        printf ']}'
    } > "$change_batch_file"

    info "Applying Route 53 changes"
    aws route53 change-resource-record-sets \
        --hosted-zone-id "$HOSTED_ZONE_ID" \
        --change-batch "file://$change_batch_file" >/dev/null

    info "Route 53 records updated."

    printf "\nRoute 53 nameservers:\n"
    aws route53 get-hosted-zone --id "$HOSTED_ZONE_ID" --query "DelegationSet.NameServers[]" --output table
else
    warn "Skipping Route 53 changes. Create the validation records and apex alias manually."
fi

printf "\nCurrent domain status: %s\n" "$(describe_domain_status "$SERVICE_ARN" "$AWS_REGION" "$DOMAIN")"
printf "Service URL: %s\n" "$SERVICE_URL"
printf "Next check: make domain-status\n"
