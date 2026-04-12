# Load configuration
. "$PSScriptRoot\config.ps1"

Write-Host "==============================================================================" -ForegroundColor Red
Write-Host "CLEANUP: Removing AWS Resources for $REPO_NAME" -ForegroundColor Red
Write-Host "==============================================================================" -ForegroundColor Red
Write-Host "⚠️  This will DELETE your App Runner service and ECR images!" -ForegroundColor Yellow
Write-Host ""

$confirmation = Read-Host "Type 'DELETE' to confirm removal of $REPO_NAME"
if ($confirmation -ne "DELETE") {
    Write-Host "❌ Cleanup cancelled" -ForegroundColor Yellow
    exit 0
}

# Step 1: Delete App Runner Service
Write-Host "Step 1: Deleting App Runner service..." -ForegroundColor Yellow
try {
    aws apprunner delete-service `
        --service-arn "arn:aws:apprunner:${AWS_REGION}:${AWS_ACCOUNT_ID}:service/$REPO_NAME" `
        --region $AWS_REGION

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ App Runner service deletion initiated" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  App Runner service may not exist or already deleted" -ForegroundColor Yellow
}

# Step 2: Delete ECR Images
Write-Host "Step 2: Deleting ECR images..." -ForegroundColor Yellow
try {
    aws ecr list-images --repository-name $REPO_NAME --region $AWS_REGION --query 'imageIds[*]' --output json | `
    aws ecr batch-delete-image --repository-name $REPO_NAME --region $AWS_REGION --image-ids file:///dev/stdin

    Write-Host "✅ ECR images deleted" -ForegroundColor Green
} catch {
    Write-Host "⚠️  No ECR images to delete" -ForegroundColor Yellow
}

# Step 3: Delete ECR Repository
Write-Host "Step 3: Deleting ECR repository..." -ForegroundColor Yellow
try {
    aws ecr delete-repository --repository-name $REPO_NAME --region $AWS_REGION --force

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ ECR repository deleted" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  ECR repository may not exist" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Green
Write-Host "CLEANUP COMPLETE" -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Green