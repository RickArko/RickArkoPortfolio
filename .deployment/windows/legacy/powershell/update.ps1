# Load configuration
. "$PSScriptRoot\config.ps1"

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "Updating App Runner Service: $REPO_NAME" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan

# Step 1: Build and Push New Image
Write-Host "Step 1: Building new Docker image..." -ForegroundColor Yellow
docker build -t $LOCAL_IMAGE .
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Docker build failed" -ForegroundColor Red
    exit 1
}

Write-Host "Step 2: Pushing updated image..." -ForegroundColor Yellow
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
docker tag $LOCAL_IMAGE $ECR_IMAGE
docker push $ECR_IMAGE

# Step 2: Trigger App Runner Deployment
Write-Host "Step 3: Triggering App Runner deployment..." -ForegroundColor Yellow

try {
    $result = aws apprunner start-deployment `
        --service-arn "arn:aws:apprunner:${AWS_REGION}:${AWS_ACCOUNT_ID}:service/$REPO_NAME" `
        --region $AWS_REGION `
        --output json

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Deployment started successfully" -ForegroundColor Green
        $deploymentInfo = $result | ConvertFrom-Json
        Write-Host "Deployment ID: $($deploymentInfo.OperationId)"
    }
} catch {
    Write-Host "❌ Failed to start deployment" -ForegroundColor Red
    Write-Host "Service ARN might be incorrect or service doesn't exist" -ForegroundColor Yellow
}