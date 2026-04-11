# Simple working script to fix the domain
$DOMAIN = "rickarko.com"
$SERVICE_ARN = "arn:aws:apprunner:us-east-1:122610507380:service/RickArko_Portfolio/c19016262e9e4c578b072cf6b09dd7d7"
$REGION = "us-east-1"
$HOSTED_ZONE_ID = "Z08302203OZOEJNRETXLE"

Write-Host "Getting App Runner service URL..." -ForegroundColor Green
$serviceInfo = aws apprunner describe-service --service-arn $SERVICE_ARN --region $REGION --output json | ConvertFrom-Json
$SERVICE_URL = $serviceInfo.Service.ServiceUrl
Write-Host "Service URL: $SERVICE_URL" -ForegroundColor Yellow

Write-Host "Creating CNAME record..." -ForegroundColor Green
$changeJson = @"
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

$changeJson | Out-File -FilePath "temp-change.json" -Encoding UTF8
aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch file://temp-change.json
Remove-Item "temp-change.json" -Force

Write-Host "DNS record created. Testing in 30 seconds..." -ForegroundColor Green
Start-Sleep 30

Write-Host "Testing domain..." -ForegroundColor Green
nslookup $DOMAIN

Write-Host "Testing HTTPS..." -ForegroundColor Green
try {
    $response = Invoke-WebRequest -Uri "https://$DOMAIN" -Method Head -TimeoutSec 15 -ErrorAction Stop
    Write-Host "SUCCESS: Domain is working! Status: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "Still not ready: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "Check App Runner status:" -ForegroundColor Green
aws apprunner describe-custom-domains --service-arn $SERVICE_ARN --region $REGION --query 'CustomDomains[0].Status' --output text
