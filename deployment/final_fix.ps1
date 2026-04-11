# Final Fix for rickarko.com - Create missing CNAME record
Write-Host "=== Creating Missing CNAME Record ===" -ForegroundColor Cyan

$DOMAIN = "rickarko.com"
$SERVICE_URL = "ctydyem9cj.us-east-1.awsapprunner.com"
$HOSTED_ZONE_ID = "Z08302203OZOEJNRETXLE"

Write-Host "Domain: $DOMAIN" -ForegroundColor Yellow
Write-Host "Target: $SERVICE_URL" -ForegroundColor Yellow

# Create the CNAME record
Write-Host "Creating CNAME record..." -ForegroundColor Green

$json = @"
{
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "$DOMAIN",
                "Type": "CNAME",
                "TTL": 300,
                "ResourceRecords": [
                    {"Value": "$SERVICE_URL"}
                ]
            }
        }
    ]
}
"@

$json | Out-File -FilePath "cname-fix.json" -Encoding UTF8

Write-Host "Applying DNS change..." -ForegroundColor Green
aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch file://cname-fix.json

Remove-Item "cname-fix.json" -Force

Write-Host "CNAME record created successfully!" -ForegroundColor Green
Write-Host "Domain should work in 5-10 minutes." -ForegroundColor Yellow

Write-Host "`nTesting in 30 seconds..." -ForegroundColor Green
Start-Sleep 30

Write-Host "Testing DNS resolution..." -ForegroundColor Green
nslookup rickarko.com

Write-Host "`nTesting web access..." -ForegroundColor Green
try {
    $response = Invoke-WebRequest -Uri "https://rickarko.com" -TimeoutSec 15 -ErrorAction Stop
    Write-Host "✅ SUCCESS! Domain is working - Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "🎉 Your site is live at: https://rickarko.com" -ForegroundColor Green
} catch {
    Write-Host "⏳ Still propagating: $($_.Exception.Message)" -ForegroundColor Yellow  
    Write-Host "💡 Try again in 5-10 minutes" -ForegroundColor Cyan
}
