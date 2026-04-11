# Configure Variables
$LOCAL_IMAGE = "rickarko_portfolio:latest"
$AWS_ECR_REPO = "rickarko_portfolio"  # The ECR repository name
$AWS_ACCOUNT_ID = (aws sts get-caller-identity --query 'Account' --output text)
$AWS_REGION = "us-east-1"  # Change if using different region

Write-Host "AWS Build Local Image: $LOCAL_IMAGE AND Push to ECR: $AWS_ECR_REPO FOR: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

Create the ECR Repository
aws ecr create-repository --repository-name $AWS_ECR_REPO

# Build Local Image if does not exist
docker build -t $LOCAL_IMAGE .

# Tag the image and push to ECR
Write-Host "Tagging and pushing image to ECR..."
Write-Host "docker tag $LOCAL_IMAGE $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$AWS_ECR_REPO:latest"

docker tag $LOCAL_IMAGE "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$AWS_ECR_REPO:latest"
docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$AWS_ECR_REPO:latest"

Write-Host "Image pushed to: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$AWS_ECR_REPO:latest"