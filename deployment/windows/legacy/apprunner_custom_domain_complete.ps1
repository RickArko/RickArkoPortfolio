# Complete AWS App Runner Custom Domain Setup Script
# This script handles the entire process of setting up a custom domain for App Runner
# Based on lessons learned from rickarko.com setup

# ===== CONFIGURATION VARIABLES =====
# UPDATE THESE FOR YOUR PROJECT:
$DOMAIN = "rickarko.com"                    # Your custom domain name
$SERVICE_NAME = "RickArko_Portfolio"        # Exact App Runner service name (case-sensitive)
$REGION = "us-east-1"                       # AWS region where your App Runner service is deployed

# ===== SCRIPT EXECUTION =====
Write-Host "=== Complete App Runner Custom Domain Setup ===" -ForegroundColor Cyan
Write-Host "Domain: $DOMAIN" -ForegroundColor Yellow
Write-Host "Service: $SERVICE_NAME" -ForegroundColor Yellow
Write-Host "Region: $REGION" -ForegroundColor Yellow
Write-Host ""

# Step 1: Create or verify Route 53 hosted zone
Write-Host "Step 1: Setting up Route 53 hosted zone..." -ForegroundColor Green
$HOSTED_ZONE_ID = $null

try {
    # Try to create hosted zone
    $timestamp = [int][double]::Parse((Get-Date -UFormat %s))
    $hostedZoneResponse = aws route53 create-hosted-zone --name $DOMAIN --caller-reference "setup-$timestamp" --output json | ConvertFrom-Json
    $HOSTED_ZONE_ID = $hostedZoneResponse.HostedZone.Id.Split('/')[-1]
    Write-Host "✓ Created new hosted zone: $HOSTED_ZONE_ID" -ForegroundColor Green
} catch {
    # If creation fails, try to find existing zone
    Write-Host "⚠ Hosted zone may already exist. Checking..." -ForegroundColor Yellow
    $existingZones = aws route53 list-hosted-zones-by-name --dns-name $DOMAIN --output json | ConvertFrom-Json
    if ($existingZones.HostedZones.Count -gt 0) {
        $HOSTED_ZONE_ID = $existingZones.HostedZones[0].Id.Split('/')[-1]
        Write-Host "✓ Using existing hosted zone: $HOSTED_ZONE_ID" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to create or find hosted zone" -ForegroundColor Red
        exit 1
    }
}

# Step 2: Display nameservers for domain registrar
Write-Host ""
Write-Host "Step 2: Domain Registrar Nameserver Update Required" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "⚠ UPDATE THESE NAMESERVERS AT YOUR DOMAIN REGISTRAR:" -ForegroundColor Red
aws route53 get-hosted-zone --id $HOSTED_ZONE_ID --query 'DelegationSet.NameServers[]' --output table
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Instructions:" -ForegroundColor Yellow
Write-Host "1. Login to your domain registrar (GoDaddy, Namecheap, etc.)" -ForegroundColor Gray
Write-Host "2. Find domain management for $DOMAIN" -ForegroundColor Gray  
Write-Host "3. Change nameservers from 'Default' to 'Custom'" -ForegroundColor Gray
Write-Host "4. Replace with the AWS nameservers shown above" -ForegroundColor Gray
Write-Host "5. Save changes (may take 5-30 minutes to propagate)" -ForegroundColor Gray

# Step 3: Get App Runner service details
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

# Get service URL for DNS record
$serviceDetails = aws apprunner describe-service --service-arn $SERVICE_ARN --region $REGION --output json | ConvertFrom-Json
$SERVICE_URL = $serviceDetails.Service.ServiceUrl

Write-Host "✓ Found service: $SERVICE_NAME" -ForegroundColor Green
Write-Host "✓ Service ARN: $SERVICE_ARN" -ForegroundColor Green
Write-Host "✓ Service URL: $SERVICE_URL" -ForegroundColor Green

# Step 4: Associate custom domain with App Runner
Write-Host ""
Write-Host "Step 4: Associating domain with App Runner..." -ForegroundColor Green
aws apprunner associate-custom-domain --service-arn $SERVICE_ARN --domain-name $DOMAIN --region $REGION --output json | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Domain association initiated successfully!" -ForegroundColor Green
} else {
    Write-Host "⚠ Domain may already be associated (this is OK)" -ForegroundColor Yellow
}

# Step 5: Create DNS CNAME record pointing to App Runner service
Write-Host ""
Write-Host "Step 5: Creating DNS records in Route 53..." -ForegroundColor Green

$changeJson = @{
    Changes = @(
        @{
            Action = "UPSERT"
            ResourceRecordSet = @{
                Name = $DOMAIN
                Type = "CNAME"
                TTL = 300
                ResourceRecords = @(
                    @{ Value = $SERVICE_URL }
                )
            }
        }
    )
} | ConvertTo-Json -Depth 10

# Save change batch to temp file
$changeFile = "dns-change-$([System.IO.Path]::GetRandomFileName()).json"
$changeJson | Out-File -FilePath $changeFile -Encoding UTF8

try {
    # Apply DNS change
    $changeResponse = aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch "file://$changeFile" --output json | ConvertFrom-Json
    Write-Host "✓ DNS CNAME record created: $DOMAIN → $SERVICE_URL" -ForegroundColor Green
    Write-Host "✓ Change ID: $($changeResponse.ChangeInfo.Id)" -ForegroundColor Green
} catch {
    Write-Host "⚠ DNS record creation may have failed, but continuing..." -ForegroundColor Yellow
} finally {
    # Clean up temp file
    if (Test-Path $changeFile) {
        Remove-Item $changeFile -Force
    }
}

# Step 6: Check initial status and provide monitoring info
Write-Host ""
Write-Host "Step 6: Initial status check..." -ForegroundColor Green
$domainStatus = aws apprunner describe-custom-domains --service-arn $SERVICE_ARN --region $REGION --query 'CustomDomains[0].Status' --output text
Write-Host "Current App Runner status: $domainStatus" -ForegroundColor $(if ($domainStatus -eq "active") {"Green"} elseif ($domainStatus -like "*pending*") {"Yellow"} else {"Red"})

# Create monitoring scripts for easy status checking
$statusScript = @"
# Quick status check for $DOMAIN
Write-Host "=== Domain Status Check: $DOMAIN ===" -ForegroundColor Cyan

# 1. Check nameservers
Write-Host "1. Nameserver Status:" -ForegroundColor Green
nslookup -type=NS $DOMAIN

# 2. Check App Runner domain status  
Write-Host "`n2. App Runner Status:" -ForegroundColor Green
aws apprunner describe-custom-domains --service-arn "$SERVICE_ARN" --region $REGION --query 'CustomDomains[0].Status'

# 3. Test domain connectivity
Write-Host "`n3. Domain Connectivity:" -ForegroundColor Green
try {
    `$response = Invoke-WebRequest -Uri "https://$DOMAIN" -Method Head -TimeoutSec 10 -ErrorAction Stop
    Write-Host "✓ SUCCESS: https://$DOMAIN is working! (Status: `$(`$response.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "⏳ Not ready yet: `$(`$_.Exception.Message)" -ForegroundColor Yellow
}
"@

Set-Content -Path "check_domain_status.ps1" -Value $statusScript

# Final instructions
Write-Host ""
Write-Host "=== NEXT STEPS ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. ⚠️  CRITICAL: Update nameservers at your domain registrar" -ForegroundColor Red
Write-Host "   Use the AWS nameservers displayed above" -ForegroundColor Gray
Write-Host ""
Write-Host "2. ⏱️  Wait for DNS propagation (5-30 minutes)" -ForegroundColor Yellow
Write-Host ""
Write-Host "3. 🔍 Monitor progress:" -ForegroundColor Green  
Write-Host "   .\check_domain_status.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "4. 📊 Expected status progression:" -ForegroundColor Green
Write-Host "   pending_certificate_dns_validation → pending_domain_dns_validation → active ✓" -ForegroundColor Gray
Write-Host ""
Write-Host "5. 🚀 Test your domain once status is 'active':" -ForegroundColor Green
Write-Host "   https://$DOMAIN" -ForegroundColor Gray

Write-Host ""
Write-Host "✓ Setup complete! Monitor with: .\check_domain_status.ps1" -ForegroundColor Green
Write-Host "✓ Total expected time: 30-60 minutes" -ForegroundColor Green
