#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

DOMAIN="${DOMAIN:-$DOMAIN_DEFAULT}"
SERVICE_NAME="${SERVICE_NAME:-$SERVICE_NAME_DEFAULT}"
SERVICE_ARN="${SERVICE_ARN:-}"
AWS_REGION="${AWS_REGION:-$AWS_REGION_DEFAULT}"
HOSTED_ZONE_ID="${HOSTED_ZONE_ID:-}"
WATCH_MODE=0
INTERVAL=30
DETAILED=0

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
        --watch)
            WATCH_MODE=1
            ;;
        --interval)
            INTERVAL="$2"
            shift
            ;;
        --detailed)
            DETAILED=1
            ;;
        --help|-h)
            cat <<'EOF'
Usage: ./deployment/bin/apprunner-domain-status.sh [options]

Options:
  --domain <domain>          Custom domain name
  --service-name <name>      App Runner service name
  --service-arn <arn>        App Runner service ARN
  --region <region>          AWS region
  --hosted-zone-id <zone>    Route 53 hosted zone ID
  --watch                    Refresh continuously
  --interval <seconds>       Refresh interval for watch mode (default: 30)
  --detailed                 Show certificate validation and Route 53 details
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

if [[ -z "$HOSTED_ZONE_ID" ]]; then
    HOSTED_ZONE_ID="$(lookup_hosted_zone_id "$DOMAIN" || true)"
fi

render_status() {
    local service_url
    service_url="$(describe_service_url "$SERVICE_ARN" "$AWS_REGION")"

    section "App Runner domain status"
    printf "Domain: %s\nService: %s\nRegion: %s\nService ARN: %s\nService URL: %s\n" \
        "$DOMAIN" "$SERVICE_NAME" "$AWS_REGION" "$SERVICE_ARN" "$service_url"
    if [[ -n "$HOSTED_ZONE_ID" ]]; then
        printf "Hosted zone: %s\n" "$HOSTED_ZONE_ID"
    fi

    printf "\nCustom domains:\n"
    aws apprunner describe-custom-domains \
        --service-arn "$SERVICE_ARN" \
        --region "$AWS_REGION" \
        --query "CustomDomains[*].[DomainName,Status,EnableWWWSubdomain,DNSTarget]" \
        --output table

    if [[ "$DETAILED" -eq 1 ]]; then
        printf "\nCertificate validation records:\n"
        aws apprunner describe-custom-domains \
            --service-arn "$SERVICE_ARN" \
            --region "$AWS_REGION" \
            --query "CustomDomains[?DomainName=='${DOMAIN}'] | [0].CertificateValidationRecords[*].[Name,Value,Status]" \
            --output table
    fi

    if [[ -n "$HOSTED_ZONE_ID" ]]; then
        printf "\nRoute 53 nameservers:\n"
        aws route53 get-hosted-zone --id "$HOSTED_ZONE_ID" --query "DelegationSet.NameServers[]" --output table

        printf "\nRoute 53 root and www records:\n"
        aws route53 list-resource-record-sets \
            --hosted-zone-id "$HOSTED_ZONE_ID" \
            --query "ResourceRecordSets[?contains(['${DOMAIN}.','www.${DOMAIN}.'], Name)].[Name,Type,AliasTarget.DNSName,ResourceRecords[0].Value]" \
            --output table
    fi

    printf "\nDNS resolution:\n"
    printf "%s\n" "$DOMAIN:"
    print_dns_lookup "$DOMAIN" || true
    printf "%s\n" "www.$DOMAIN:"
    print_dns_lookup "www.$DOMAIN" || true

    printf "\nHTTPS checks:\n"
    printf "%s -> %s\n" "https://$DOMAIN" "$(http_status "https://$DOMAIN")"
    printf "%s -> %s\n" "https://www.$DOMAIN" "$(http_status "https://www.$DOMAIN")"
}

if [[ "$WATCH_MODE" -eq 1 ]]; then
    while true; do
        clear
        printf "Updated: %s\n\n" "$(date)"
        render_status
        sleep "$INTERVAL"
    done
else
    render_status
fi
