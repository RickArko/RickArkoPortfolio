# Load configuration
. "$PSScriptRoot\config.ps1"

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "Status Check for: $REPO_NAME" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan

# Check App Runner Service
Write-Host "App Runner Service Status:" -ForegroundColor Yellow
try {
    $serviceInfo = aws apprunner describe-service `
        --service-arn "arn:aws:apprunner:${AWS_REGION}:${AWS_ACCOUNT_ID}:service/$REPO_NAME" `
        --region $AWS_REGION `
        --output json | ConvertFrom-Json

    Write-Host "  Service Name: $($serviceInfo.Service.ServiceName)"
    Write-Host "  Status: $($serviceInfo.Service.Status)" -ForegroundColor $(if($serviceInfo.Service.Status -eq "RUNNING"){"Green"}else{"Yellow"})
    Write-Host "  Service URL: $($serviceInfo.Service.ServiceUrl)" -ForegroundColor Cyan
    Write-Host "  Created: $($serviceInfo.Service.CreatedAt)"
    Write-Host "  CPU: $($serviceInfo.Service.InstanceConfiguration.Cpu)"
    Write-Host "  Memory: $($serviceInfo.Service.InstanceConfiguration.Memory)"
} catch {
    Write-Host "  ❌ App Runner service not found" -ForegroundColor Red
}

Write-Host ""

# Check ECR Repository
Write-Host "ECR Repository Status:" -ForegroundColor Yellow
try {
    $repoInfo = aws ecr describe-repositories `
        --repository-names $REPO_NAME `
        --region $AWS_REGION `
        --output json | ConvertFrom-Json

    Write-Host "  Repository URI: $($repoInfo.repositories[0].repositoryUri)" -ForegroundColor Cyan
    Write-Host "  Created: $($repoInfo.repositories[0].createdAt)"

    # Check images
    $images = aws ecr list-images `
        --repository-name $REPO_NAME `
        --region $AWS_REGION `
        --output json | ConvertFrom-Json

    Write-Host "  Images: $($images.imageIds.Count) image(s)"
} catch {
    Write-Host "  ❌ ECR repository not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "🌐 AWS Console Links:" -ForegroundColor Cyan
Write-Host "  App Runner: https://console.aws.amazon.com/apprunner/home?region=$AWS_REGION"
Write-Host "  ECR: https://console.aws.amazon.com/ecr/repositories?region=$AWS_REGION"