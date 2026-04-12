# =============================================================================
# DEPLOYMENT CONFIGURATION
# =============================================================================

# REQUIRED: Set your repository/app name (lowercase, no spaces)
$REPO_NAME = "rickarkoportfolio"

# OPTIONAL: Customize these settings
$AWS_REGION = "us-east-1"
$CPU = "1 vCPU"
$MEMORY = "2 GB"
$ENVIRONMENT_VARIABLES = @(
    @{Name="FLASK_ENV"; Value="production"}
)

# ADVANCED: Override if needed
$LOCAL_IMAGE_TAG = "latest"
$ECR_IMAGE_TAG = "latest"

# =============================================================================
# AUTO-GENERATED (DO NOT MODIFY)
# =============================================================================
$AWS_ACCOUNT_ID = (aws sts get-caller-identity --query 'Account' --output text)
$ECR_URI = "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME"
$LOCAL_IMAGE = "${REPO_NAME}:${LOCAL_IMAGE_TAG}"
$ECR_IMAGE = "${ECR_URI}:${ECR_IMAGE_TAG}"