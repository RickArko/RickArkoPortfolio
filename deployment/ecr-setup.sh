# 1. Create ECR repository
aws ecr create-repository --repository-name rickarkoportfolio

# 2. Get your AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
AWS_REGION=us-east-1  # Change if you're using different region

# 3. Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# 4. Your image is already built as "rickarkoportfolio:latest" ✅

# 5. Tag the image for ECR
docker tag rickarkoportfolio:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/rickarkoportfolio:latest

# 6. Push to ECR
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/rickarkoportfolio:latest

echo "Image pushed to: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/rickarkoportfolio:latest"