#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

readonly APP_NAME_DEFAULT="rickarkoportfolio"
readonly SERVICE_NAME_DEFAULT="RickArko_Portfolio"
readonly AWS_REGION_DEFAULT="us-east-1"
readonly DOMAIN_DEFAULT="rickarko.com"
readonly APPRUNNER_HOSTED_ZONE_ID_DEFAULT="Z01915732ZBZKC8D32TPT"

if [[ -t 1 ]]; then
    readonly COLOR_RED=$'\033[0;31m'
    readonly COLOR_GREEN=$'\033[0;32m'
    readonly COLOR_YELLOW=$'\033[1;33m'
    readonly COLOR_CYAN=$'\033[0;36m'
    readonly COLOR_GRAY=$'\033[0;37m'
    readonly COLOR_RESET=$'\033[0m'
else
    readonly COLOR_RED=""
    readonly COLOR_GREEN=""
    readonly COLOR_YELLOW=""
    readonly COLOR_CYAN=""
    readonly COLOR_GRAY=""
    readonly COLOR_RESET=""
fi

section() {
    printf "%s== %s ==%s\n" "$COLOR_CYAN" "$1" "$COLOR_RESET"
}

info() {
    printf "%s%s%s\n" "$COLOR_GREEN" "$1" "$COLOR_RESET"
}

warn() {
    printf "%s%s%s\n" "$COLOR_YELLOW" "$1" "$COLOR_RESET"
}

error() {
    printf "%s%s%s\n" "$COLOR_RED" "$1" "$COLOR_RESET" >&2
}

die() {
    error "$1"
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

trim_hosted_zone_id() {
    printf "%s\n" "${1##*/}"
}

lookup_hosted_zone_id() {
    local domain="$1"
    local hosted_zone_id

    hosted_zone_id="$(aws route53 list-hosted-zones-by-name \
        --dns-name "$domain" \
        --query "HostedZones[?Name=='${domain}.'] | [0].Id" \
        --output text)"

    if [[ -z "$hosted_zone_id" || "$hosted_zone_id" == "None" ]]; then
        return 1
    fi

    trim_hosted_zone_id "$hosted_zone_id"
}

ensure_hosted_zone() {
    local domain="$1"
    local hosted_zone_id

    if hosted_zone_id="$(lookup_hosted_zone_id "$domain")"; then
        printf "%s\n" "$hosted_zone_id"
        return 0
    fi

    hosted_zone_id="$(aws route53 create-hosted-zone \
        --name "$domain" \
        --caller-reference "${domain}-$(date +%s)" \
        --query "HostedZone.Id" \
        --output text)"

    trim_hosted_zone_id "$hosted_zone_id"
}

lookup_service_arn() {
    local service_name="$1"
    local aws_region="$2"
    local service_arn

    service_arn="$(aws apprunner list-services \
        --region "$aws_region" \
        --query "ServiceSummaryList[?ServiceName=='${service_name}'] | [0].ServiceArn" \
        --output text)"

    if [[ -z "$service_arn" || "$service_arn" == "None" ]]; then
        return 1
    fi

    printf "%s\n" "$service_arn"
}

describe_service_url() {
    local service_arn="$1"
    local aws_region="$2"

    aws apprunner describe-service \
        --service-arn "$service_arn" \
        --region "$aws_region" \
        --query "Service.ServiceUrl" \
        --output text
}

describe_domain_status() {
    local service_arn="$1"
    local aws_region="$2"
    local domain="$3"

    aws apprunner describe-custom-domains \
        --service-arn "$service_arn" \
        --region "$aws_region" \
        --query "CustomDomains[?DomainName=='${domain}'] | [0].Status" \
        --output text
}

print_dns_lookup() {
    local hostname="$1"

    if command -v dig >/dev/null 2>&1; then
        dig +short "$hostname"
    elif command -v nslookup >/dev/null 2>&1; then
        nslookup "$hostname" 2>/dev/null | sed -n 's/^Address: //p'
    else
        warn "Neither dig nor nslookup is installed."
        return 1
    fi
}

http_status() {
    local url="$1"

    if ! command -v curl >/dev/null 2>&1; then
        printf "curl not installed\n"
        return 0
    fi

    curl -L -k -s -o /dev/null -w "%{http_code}" "$url" || true
}
