#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

APP_NAME="${APP_NAME:-$APP_NAME_DEFAULT}"
AWS_REGION="${AWS_REGION:-$AWS_REGION_DEFAULT}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
LOCAL_IMAGE="${LOCAL_IMAGE:-${APP_NAME}:${IMAGE_TAG}}"
SKIP_BUILD=0

while (($#)); do
    case "$1" in
        --skip-build)
            SKIP_BUILD=1
            ;;
        --help|-h)
            cat <<'EOF'
Usage: ./deployment/bin/ecr-setup.sh [--skip-build]

Environment:
  APP_NAME      ECR repository name and local image name (default: rickarkoportfolio)
  AWS_REGION    AWS region (default: us-east-1)
  IMAGE_TAG     Image tag to push (default: latest)
  LOCAL_IMAGE   Local image to tag and push (default: APP_NAME:IMAGE_TAG)
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
require_cmd docker

AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query "Account" --output text)"
REMOTE_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}:${IMAGE_TAG}"

section "ECR setup"
printf "App: %s\nRegion: %s\nAccount: %s\n\n" "$APP_NAME" "$AWS_REGION" "$AWS_ACCOUNT_ID"

if aws ecr describe-repositories --repository-names "$APP_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    info "ECR repository already exists: $APP_NAME"
else
    info "Creating ECR repository: $APP_NAME"
    aws ecr create-repository --repository-name "$APP_NAME" --region "$AWS_REGION" >/dev/null
fi

info "Authenticating Docker to ECR"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

if [[ "$SKIP_BUILD" -eq 0 ]]; then
    info "Building local image: $LOCAL_IMAGE"
    docker build -t "$LOCAL_IMAGE" "$REPO_ROOT"
else
    warn "Skipping docker build; using existing local image: $LOCAL_IMAGE"
fi

info "Tagging image"
docker tag "$LOCAL_IMAGE" "$REMOTE_IMAGE"

info "Pushing image to ECR"
docker push "$REMOTE_IMAGE"

info "Image pushed successfully"
printf "Remote image: %s\n" "$REMOTE_IMAGE"
