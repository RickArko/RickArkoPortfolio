$DOMAIN = "rickarko.com"
$SERVICE_NAME = "RickArko_Portfolio"  # Updated to match actual service name
$REGION = "us-east-1"
$HOSTED_ZONE_ID = "Z08302203OZOEJNRETXLE"  # Use existing hosted zone

Write-Host "Setting up custom domain: $DOMAIN"

# Skip hosted zone creation since it already exists
Write-Host "Using existing hosted zone: $HOSTED_ZONE_ID"

# Get nameservers (already displayed previously, but showing again for reference)
Write-Host "Nameservers to update in GoDaddy:"
aws route53 get-hosted-zone --id $HOSTED_ZONE_ID --query 'DelegationSet.NameServers' --output table

# Get App Runner service ARN with the correct service name
Write-Host "Getting App Runner service ARN..."
$SERVICE_ARN = aws apprunner list-services --region $REGION --query "ServiceSummaryList[?ServiceName=='$SERVICE_NAME'].ServiceArn" --output text

Write-Host "Service ARN: $SERVICE_ARN"

# Associate custom domain
if ($SERVICE_ARN) {
    Write-Host "Associating custom domain with App Runner..."
    aws apprunner associate-custom-domain --service-arn $SERVICE_ARN --domain-name $DOMAIN --region $REGION
} else {
    Write-Host "ERROR: Could not find service ARN"
    exit 1
}

Write-Host "Custom domain association initiated."
Write-Host "Next steps:"
Write-Host "1. Update nameservers in GoDaddy with the ones shown above"
Write-Host "2. Wait 5-10 minutes for DNS propagation"
Write-Host "3. Check status with: aws apprunner describe-custom-domains --service-arn $SERVICE_ARN --region $REGION"