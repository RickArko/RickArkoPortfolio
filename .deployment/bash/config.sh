#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/deployment/bin/common.sh"

REPO_NAME="${REPO_NAME:-rickarkoportfolio}"
SERVICE_NAME="${SERVICE_NAME:-RickArko_Portfolio}"
AWS_REGION="${AWS_REGION:-$AWS_REGION_DEFAULT}"
CPU="${CPU:-1024}"
MEMORY="${MEMORY:-2048}"
LOCAL_IMAGE_TAG="${LOCAL_IMAGE_TAG:-latest}"
ECR_IMAGE_TAG="${ECR_IMAGE_TAG:-latest}"

AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query "Account" --output text)}"
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}"
LOCAL_IMAGE="${REPO_NAME}:${LOCAL_IMAGE_TAG}"
ECR_IMAGE="${ECR_URI}:${ECR_IMAGE_TAG}"
