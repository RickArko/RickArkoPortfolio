#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

APP_NAME="${APP_NAME:-$APP_NAME_DEFAULT}"
SERVICE_NAME="${SERVICE_NAME:-$SERVICE_NAME_DEFAULT}"
AWS_REGION="${AWS_REGION:-$AWS_REGION_DEFAULT}"
DOMAIN="${DOMAIN:-$DOMAIN_DEFAULT}"
LOCAL_IMAGE="${LOCAL_IMAGE:-${APP_NAME}:latest}"
SKIP_DOCKER_BUILD=0

show_help() {
    cat <<'EOF'
Usage: ./deployment/bin/deploy-check.sh [options]

Run a stricter no-push deployment readiness check for local development.

Options:
  --skip-docker-build       Skip the local docker build validation
  --help, -h                Show this help text
EOF
}

while (($#)); do
    case "$1" in
        --skip-docker-build)
            SKIP_DOCKER_BUILD=1
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

require_cmd docker

section "Local Docker runtime"
docker info >/dev/null
info "Docker daemon is reachable."

section "AWS preflight"
APP_NAME="$APP_NAME" SERVICE_NAME="$SERVICE_NAME" AWS_REGION="$AWS_REGION" DOMAIN="$DOMAIN" \
    "$SCRIPT_DIR/aws-doctor.sh"

if [[ "$SKIP_DOCKER_BUILD" -eq 0 ]]; then
    section "Docker image build"
    info "Building local image for deployment validation: $LOCAL_IMAGE"
    docker build -t "$LOCAL_IMAGE" "$REPO_ROOT" >/dev/null
    info "Docker build succeeded."
else
    warn "Skipping docker build validation."
fi

info "Deployment readiness checks passed."
