# Load configuration
. "$PSScriptRoot\config.ps1"

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "Deploying Flask App: $REPO_NAME" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "Local Image: $LOCAL_IMAGE"
Write-Host "ECR URI: $ECR_IMAGE"
Write-Host "Region: $AWS_REGION"
Write-Host ""

# Step 1: Create ECR Repository
Write-Host "Step 1: Creating ECR Repository..." -ForegroundColor Yellow
try {
    aws ecr create-repository --repository-name $REPO_NAME --region $AWS_REGION 2>$null
    Write-Host "✅ ECR repository created (or already exists)" -ForegroundColor Green
} catch {
    Write-Host "✅ ECR repository already exists" -ForegroundColor Green
}

# Step 2: Build Docker Image
Write-Host "Step 2: Building Docker image..." -ForegroundColor Yellow
docker build -t $LOCAL_IMAGE .
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Docker build failed" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Docker image built successfully" -ForegroundColor Green

# Step 3: Login to ECR
Write-Host "Step 3: Authenticating with ECR..." -ForegroundColor Yellow
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ ECR login failed" -ForegroundColor Red
    exit 1
}
Write-Host "✅ ECR authentication successful" -ForegroundColor Green

# Step 4: Tag and Push Image
Write-Host "Step 4: Tagging and pushing image..." -ForegroundColor Yellow
docker tag $LOCAL_IMAGE $ECR_IMAGE
docker push $ECR_IMAGE
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Docker push failed" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Image pushed to ECR" -ForegroundColor Green

# Step 5: Create App Runner Service
Write-Host "Step 5: Creating App Runner service..." -ForegroundColor Yellow

# Build environment variables JSON
$envVarsJson = $ENVIRONMENT_VARIABLES | ForEach-Object { "{`"Name`": `"$($_.Name)`", `"Value`": `"$($_.Value)`"}" }
$envVarsString = "[" + ($envVarsJson -join ", ") + "]"

$sourceConfig = @{
    ImageRepository = @{
        ImageIdentifier = $ECR_IMAGE
        ImageRepositoryType = "ECR"
    }
    AutoDeploymentsEnabled = $true
} | ConvertTo-Json -Depth 3 -Compress

$instanceConfig = @{
    Cpu = $CPU
    Memory = $MEMORY
    EnvironmentVariables = $ENVIRONMENT_VARIABLES
} | ConvertTo-Json -Depth 3 -Compress

try {
    $result = aws apprunner create-service `
        --service-name $REPO_NAME `
        --source-configuration $sourceConfig `
        --instance-configuration $instanceConfig `
        --region $AWS_REGION `
        --output json
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ App Runner service created successfully" -ForegroundColor Green
        $serviceInfo = $result | ConvertFrom-Json
        Write-Host ""
        Write-Host "==============================================================================" -ForegroundColor Cyan
        Write-Host "DEPLOYMENT COMPLETE" -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor Cyan
        Write-Host "Service Name: $REPO_NAME"
        Write-Host "Service ARN: $($serviceInfo.Service.ServiceArn)"
        Write-Host "Status: $($serviceInfo.Service.Status)"
        Write-Host ""
        Write-Host "⏳ App Runner is provisioning your service..." -ForegroundColor Yellow
        Write-Host "📝 Check AWS Console for service URL once deployment completes"
        Write-Host "🌐 AWS Console: https://console.aws.amazon.com/apprunner/home?region=$AWS_REGION"
    }
} catch {
    Write-Host "❌ Failed to create App Runner service" -ForegroundColor Red
    Write-Host "This might be because the service already exists." -ForegroundColor Yellow
    Write-Host "Check the AWS Console or run update.ps1 to update existing service" -ForegroundColor Yellow
}