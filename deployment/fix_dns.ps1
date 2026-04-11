# Fix App Runner DNS Validation
# This script adds the missing DNS records that App Runner needs

$HOSTED_ZONE_ID = "Z08302203OZOEJNRETXLE"
$DOMAIN = "rickarko.com"
$SERVICE_ARN = "arn:aws:apprunner:us-east-1:122610507380:service/RickArko_Portfolio/c19016262e9e4c578b072cf6b09dd7d7"
$REGION = "us-east-1"

Write-Host "=== Fixing App Runner DNS Records ===" -ForegroundColor Cyan

# Get the App Runner service URL (this is what the domain should point to)
$serviceInfo = aws apprunner describe-service --service-arn $SERVICE_ARN --region $REGION --output json | ConvertFrom-Json
$serviceUrl = $serviceInfo.Service.ServiceUrl

Write-Host "Service URL: $serviceUrl" -ForegroundColor Yellow

# Create CNAME record pointing rickarko.com to the App Runner service
$changeJson = @{
    Changes = @(
        @{
            Action = "UPSERT"
            ResourceRecordSet = @{
                Name = $DOMAIN
                Type = "CNAME"
                TTL = 300
                ResourceRecords = @(
                    @{ Value = $serviceUrl }
                )
            }
        }
    )
} | ConvertTo-Json -Depth 10

# Save to temp file and create the record
$changeJson | Out-File -FilePath "dns-change.json" -Encoding UTF8

Write-Host "Creating DNS record: $DOMAIN -> $serviceUrl" -ForegroundColor Green
aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch file://dns-change.json

# Clean up
Remove-Item "dns-change.json" -Force

Write-Host "DNS record created. Wait 5-10 minutes for propagation." -ForegroundColor Green
Write-Host "Then check: https://$DOMAIN" -ForegroundColor Yellow
