# Domain Setup Verification Script
param([switch]$Detailed)

$DOMAIN = "rickarko.com"
$SERVICE_ARN = "arn:aws:apprunner:us-east-1:122610507380:service/RickArko_Portfolio/c19016262e9e4c578b072cf6b09dd7d7"
$REGION = "us-east-1"

Write-Host "=== Domain Setup Status Check ===" -ForegroundColor Cyan
Write-Host "Domain: $DOMAIN" -ForegroundColor Yellow
Write-Host ""

# 1. Check App Runner domain status
Write-Host "1. App Runner Domain Status:" -ForegroundColor Green
$status = aws apprunner describe-custom-domains --service-arn $SERVICE_ARN --region $REGION --query 'CustomDomains[0].Status' --output text
if ($status -eq "active") {
    Write-Host "   Status: $status" -ForegroundColor Green
} elseif ($status -like "*pending*") {
    Write-Host "   Status: $status" -ForegroundColor Yellow
} else {
    Write-Host "   Status: $status" -ForegroundColor Red
}

# 2. Check nameservers
Write-Host ""
Write-Host "2. Current Nameservers:" -ForegroundColor Green
try {
    $nsLookup = nslookup -type=NS $DOMAIN 2>$null
    $nameservers = $nsLookup | Where-Object { $_ -match "nameserver" }
    
    $isAWSNS = $false
    foreach ($line in $nameservers) {
        $ns = ($line -split "=")[1].Trim()
        if ($ns -like "*awsdns*") {
            Write-Host "   ✓ $ns" -ForegroundColor Green
            $isAWSNS = $true
        } else {
            Write-Host "   ❌ $ns (needs to be AWS nameserver)" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "   Could not retrieve nameservers" -ForegroundColor Yellow
    $isAWSNS = $false
}

# 3. Status summary
Write-Host ""
Write-Host "3. Summary:" -ForegroundColor Green

if ($isAWSNS -and $status -eq "active") {
    Write-Host "   🎉 SUCCESS: Domain is fully configured and active!" -ForegroundColor Green
    Write-Host "   🚀 Test your site: https://$DOMAIN" -ForegroundColor Green
} elseif ($isAWSNS -and $status.Contains("pending")) {
    Write-Host "   ⏳ IN PROGRESS: Nameservers updated, waiting for validation..." -ForegroundColor Yellow
    Write-Host "   ⏱ Expected time: 5-15 more minutes" -ForegroundColor Yellow
} elseif (-not $isAWSNS) {
    Write-Host "   ⚠ ACTION REQUIRED: Update nameservers in GoDaddy" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Expected AWS nameservers:" -ForegroundColor Yellow
    foreach ($ns in $expectedNS) {
        Write-Host "     - $ns" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "   Instructions:" -ForegroundColor Cyan
    Write-Host "   1. Log into GoDaddy" -ForegroundColor Gray
    Write-Host "   2. Go to Domain Management for $DOMAIN" -ForegroundColor Gray
    Write-Host "   3. Change nameservers from 'Default' to 'Custom'" -ForegroundColor Gray
    Write-Host "   4. Replace with the AWS nameservers listed above" -ForegroundColor Gray
} else {
    Write-Host "   ❓ Unknown status - check detailed output" -ForegroundColor Yellow
}

if ($Detailed) {
    Write-Host ""
    Write-Host "=== Detailed App Runner Info ===" -ForegroundColor Cyan
    aws apprunner describe-custom-domains --service-arn $SERVICE_ARN --region $REGION --output table
}

Write-Host ""
Write-Host "Run again with -Detailed for more information" -ForegroundColor Gray
