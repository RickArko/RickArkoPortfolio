#!/usr/bin/env bash
# Restore a previously-published ECR image to production.
#
# Usage: rollback.sh --to <imageDigest> [--service-arn <arn>] [--region <r>]
#                    [--repo <ecr-repo>] [--skip-smoke]
#
# The digest is the sha256:... identifier of the image we want to promote
# back to :latest. rollback.sh retags that digest as :latest in ECR, triggers
# an App Runner deployment, waits for it, then runs the public smoke test.
#
# Exit codes:
#   0  rollback succeeded and smoke-test is green
#   1  rollback attempted but failed somewhere (prod state uncertain — page a human)
#   2  inputs invalid / nothing to roll back to

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

TARGET_DIGEST=""
SERVICE_ARN="${APPRUNNER_SERVICE_ARN:-}"
AWS_REGION="${AWS_REGION:-$AWS_REGION_DEFAULT}"
ECR_REPOSITORY="${ECR_REPOSITORY:-$APP_NAME_DEFAULT}"
SKIP_SMOKE="false"
BASE_URL="${BASE_URL:-https://rickarko.com}"

usage() {
    cat <<'USAGE'
Usage: rollback.sh --to <imageDigest> [options]

Required:
  --to <digest>        sha256:... digest of the image to promote back to :latest

Options:
  --service-arn <arn>  App Runner service ARN (default: $APPRUNNER_SERVICE_ARN)
  --region <region>    AWS region (default: $AWS_REGION or us-east-1)
  --repo <repo>        ECR repository (default: $ECR_REPOSITORY or rickarko_portfolio)
  --skip-smoke         skip post-rollback HTTP smoke test (not recommended)
  -h, --help           show this help
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --to)           TARGET_DIGEST="$2"; shift 2 ;;
        --service-arn)  SERVICE_ARN="$2"; shift 2 ;;
        --region)       AWS_REGION="$2"; shift 2 ;;
        --repo)         ECR_REPOSITORY="$2"; shift 2 ;;
        --skip-smoke)   SKIP_SMOKE="true"; shift ;;
        -h|--help)      usage; exit 0 ;;
        *)              error "unknown argument: $1"; usage; exit 2 ;;
    esac
done

[[ -z "$TARGET_DIGEST" ]]   && { error "--to <imageDigest> is required"; exit 2; }
[[ -z "$SERVICE_ARN" ]]     && { error "--service-arn (or APPRUNNER_SERVICE_ARN env) is required"; exit 2; }
[[ "$TARGET_DIGEST" != sha256:* ]] && { error "--to must be a sha256:... digest, got: $TARGET_DIGEST"; exit 2; }

require_cmd aws

section "Rollback plan"
info "  repository : $ECR_REPOSITORY"
info "  region     : $AWS_REGION"
info "  service    : $SERVICE_ARN"
info "  target     : $TARGET_DIGEST"

# -----------------------------------------------------------------------------
# 1. Idempotency guard: refuse if target already == current :latest
# -----------------------------------------------------------------------------
current_latest_digest="$(
    aws ecr describe-images \
        --repository-name "$ECR_REPOSITORY" \
        --region "$AWS_REGION" \
        --image-ids imageTag=latest \
        --query 'imageDetails[0].imageDigest' \
        --output text 2>/dev/null || true
)"

if [[ "$current_latest_digest" == "$TARGET_DIGEST" ]]; then
    warn "Target digest already tagged :latest in ECR. Proceeding to redeploy only."
else
    section "Retagging $TARGET_DIGEST as :latest"
    manifest="$(
        aws ecr batch-get-image \
            --repository-name "$ECR_REPOSITORY" \
            --region "$AWS_REGION" \
            --image-ids "imageDigest=$TARGET_DIGEST" \
            --query 'images[0].imageManifest' \
            --output text
    )"

    if [[ -z "$manifest" || "$manifest" == "None" ]]; then
        error "Could not fetch manifest for $TARGET_DIGEST — does it still exist in ECR?"
        exit 1
    fi

    aws ecr put-image \
        --repository-name "$ECR_REPOSITORY" \
        --region "$AWS_REGION" \
        --image-tag latest \
        --image-manifest "$manifest" >/dev/null

    info "✓ :latest now points at $TARGET_DIGEST"
fi

# -----------------------------------------------------------------------------
# 2. Trigger App Runner deployment
# -----------------------------------------------------------------------------
section "Triggering App Runner deployment"
operation_id="$(
    aws apprunner start-deployment \
        --service-arn "$SERVICE_ARN" \
        --region "$AWS_REGION" \
        --query 'OperationId' \
        --output text
)"
info "  operation id: $operation_id"

# -----------------------------------------------------------------------------
# 3. Poll for operation completion
# -----------------------------------------------------------------------------
section "Waiting for rollback deployment to complete"
completed="false"
for attempt in $(seq 1 60); do
    status="$(
        aws apprunner list-operations \
            --service-arn "$SERVICE_ARN" \
            --region "$AWS_REGION" \
            --query "OperationSummaryList[?Id=='${operation_id}'] | [0].Status" \
            --output text
    )"

    case "$status" in
        SUCCEEDED|SUCCESS)
            info "  rollback deployment completed: $status"
            completed="true"
            break
            ;;
        FAILED|ROLLBACK_FAILED|CANCELLED|CREATE_FAILED|DELETE_FAILED)
            error "rollback deployment entered terminal failure: $status"
            exit 1
            ;;
        *)
            info "  attempt ${attempt}/60: status=${status}; sleeping 10s"
            sleep 10
            ;;
    esac
done

if [[ "$completed" != "true" ]]; then
    error "timed out waiting for rollback deployment operation $operation_id"
    exit 1
fi

# -----------------------------------------------------------------------------
# 4. Post-rollback smoke test
# -----------------------------------------------------------------------------
if [[ "$SKIP_SMOKE" == "true" ]]; then
    warn "Skipping post-rollback smoke test per --skip-smoke"
    exit 0
fi

section "Post-rollback smoke test"
if "$SCRIPT_DIR/smoke-test.sh" "$BASE_URL"; then
    info "✓ Rollback complete. Prod is on $TARGET_DIGEST and smoke-test is green."
    exit 0
fi

error "Rollback redeploy finished but smoke test failed against $BASE_URL."
error "Prod is in an uncertain state. Investigate immediately."
exit 1
