# AWS App Runner Custom Domain Setup Script (PowerShell)
# This script sets up a custom domain for an AWS App Runner service using Route 53

# ===== CONFIGURATION VARIABLES =====
# Update these variables for your specific project:
$DOMAIN = "rickarko.com"                    # Your custom domain name
$SERVICE_NAME = "RickArko_Portfolio"        # Exact App Runner service name (case-sensitive)
$REGION = "us-east-1"                       # AWS region where your App Runner service is deployed

# ===== SCRIPT EXECUTION =====
Write-Host "=== AWS App Runner Custom Domain Setup ===" -ForegroundColor Cyan
Write-Host "Domain: $DOMAIN" -ForegroundColor Yellow
Write-Host "Service: $SERVICE_NAME" -ForegroundColor Yellow
Write-Host "Region: $REGION" -ForegroundColor Yellow
Write-Host ""

# Step 1: Create Route 53 Hosted Zone
Write-Host "Step 1: Creating Route 53 hosted zone for $DOMAIN..." -ForegroundColor Green
try {
    $timestamp = [int][double]::Parse((Get-Date -UFormat %s))
    $hostedZoneResponse = aws route53 create-hosted-zone --name $DOMAIN --caller-reference "setup-$timestamp" --output json | ConvertFrom-Json
    $HOSTED_ZONE_ID = $hostedZoneResponse.HostedZone.Id.Split('/')[-1]
    Write-Host "✓ Hosted Zone Created: $HOSTED_ZONE_ID" -ForegroundColor Green
} catch {
    Write-Host "⚠ Hosted zone may already exist. Checking existing zones..." -ForegroundColor Yellow
    $existingZones = aws route53 list-hosted-zones-by-name --dns-name $DOMAIN --output json | ConvertFrom-Json
    $HOSTED_ZONE_ID = $existingZones.HostedZones[0].Id.Split('/')[-1]
    Write-Host "✓ Using existing hosted zone: $HOSTED_ZONE_ID" -ForegroundColor Green
}

# Step 2: Display nameservers for domain registrar update
Write-Host ""
Write-Host "Step 2: Nameservers to update at your domain registrar:" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Cyan
aws route53 get-hosted-zone --id $HOSTED_ZONE_ID --query 'DelegationSet.NameServers[]' --output table
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "⚠ IMPORTANT: Update these nameservers at your domain registrar (GoDaddy, Namecheap, etc.)" -ForegroundColor Red

# Step 3: Get App Runner service ARN
Write-Host ""
Write-Host "Step 3: Finding App Runner service..." -ForegroundColor Green
$servicesJson = aws apprunner list-services --region $REGION --output json
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Error: Failed to list App Runner services. Check AWS CLI configuration." -ForegroundColor Red
    exit 1
}

$services = $servicesJson | ConvertFrom-Json
$SERVICE_ARN = $services.ServiceSummaryList | Where-Object { $_.ServiceName -eq $SERVICE_NAME } | Select-Object -ExpandProperty ServiceArn

if (-not $SERVICE_ARN) {
    Write-Host "✗ Error: Service '$SERVICE_NAME' not found." -ForegroundColor Red
    Write-Host "Available services:" -ForegroundColor Yellow
    foreach ($service in $services.ServiceSummaryList) {
        Write-Host "  - $($service.ServiceName)" -ForegroundColor Yellow
    }
    exit 1
}

Write-Host "✓ Found service ARN: $SERVICE_ARN" -ForegroundColor Green

# Step 4: Associate custom domain with App Runner
Write-Host ""
Write-Host "Step 4: Associating custom domain with App Runner..." -ForegroundColor Green
aws apprunner associate-custom-domain --service-arn $SERVICE_ARN --domain-name $DOMAIN --region $REGION --output json | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Custom domain association initiated successfully!" -ForegroundColor Green
} else {
    Write-Host "✗ Error: Failed to associate custom domain" -ForegroundColor Red
    exit 1
}

# Step 5: Check initial status
Write-Host ""
Write-Host "Step 5: Checking domain validation status..." -ForegroundColor Green
$domainStatus = aws apprunner describe-custom-domains --service-arn $SERVICE_ARN --region $REGION --query 'CustomDomains[0].Status' --output text
Write-Host "Current status: $domainStatus" -ForegroundColor Yellow

# Final instructions
Write-Host ""
Write-Host "=== NEXT STEPS ===" -ForegroundColor Cyan
Write-Host "1. ⚠ UPDATE NAMESERVERS at your domain registrar with the ones shown above" -ForegroundColor Red
Write-Host "2. ⏱ Wait 5-30 minutes for DNS propagation (can take up to 24-48 hours)" -ForegroundColor Yellow
Write-Host "3. 🔍 Monitor status with this command:" -ForegroundColor Green
Write-Host "   aws apprunner describe-custom-domains --service-arn `"$SERVICE_ARN`" --region $REGION --query 'CustomDomains[0].Status'" -ForegroundColor Gray
Write-Host ""
Write-Host "Expected status progression:" -ForegroundColor Green
Write-Host "  pending_certificate_dns_validation → pending_domain_dns_validation → active ✓" -ForegroundColor Gray
Write-Host ""
Write-Host "4. 🚀 Once status is 'active', test your domain: https://$DOMAIN" -ForegroundColor Green

# Create monitoring script
$monitorScript = @"
# Quick status check script
aws apprunner describe-custom-domains --service-arn "$SERVICE_ARN" --region $REGION --query 'CustomDomains[0].Status' --output text
"@

Set-Content -Path "check_domain_status.ps1" -Value $monitorScript
Write-Host ""
Write-Host "✓ Created 'check_domain_status.ps1' for easy status monitoring" -ForegroundColor Green
