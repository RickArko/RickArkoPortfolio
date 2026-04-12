#!/bin/bash
# AWS App Runner Custom Domain Setup Script (Bash)
# This script sets up a custom domain for an AWS App Runner service using Route 53

# ===== CONFIGURATION VARIABLES =====
# Update these variables for your specific project:
DOMAIN="rickarko.com"                    # Your custom domain name
SERVICE_NAME="RickArko_Portfolio"        # Exact App Runner service name (case-sensitive)
REGION="us-east-1"                       # AWS region where your App Runner service is deployed

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# ===== SCRIPT EXECUTION =====
echo -e "${CYAN}=== AWS App Runner Custom Domain Setup ===${NC}"
echo -e "${YELLOW}Domain: $DOMAIN${NC}"
echo -e "${YELLOW}Service: $SERVICE_NAME${NC}"
echo -e "${YELLOW}Region: $REGION${NC}"
echo ""

# Step 1: Create Route 53 Hosted Zone
echo -e "${GREEN}Step 1: Creating Route 53 hosted zone for $DOMAIN...${NC}"
timestamp=$(date +%s)
hostedZoneResponse=$(aws route53 create-hosted-zone --name "$DOMAIN" --caller-reference "setup-$timestamp" --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    HOSTED_ZONE_ID=$(echo "$hostedZoneResponse" | jq -r '.HostedZone.Id' | cut -d'/' -f3)
    echo -e "${GREEN}✓ Hosted Zone Created: $HOSTED_ZONE_ID${NC}"
else
    echo -e "${YELLOW}⚠ Hosted zone may already exist. Checking existing zones...${NC}"
    existingZones=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN" --output json)
    HOSTED_ZONE_ID=$(echo "$existingZones" | jq -r '.HostedZones[0].Id' | cut -d'/' -f3)
    echo -e "${GREEN}✓ Using existing hosted zone: $HOSTED_ZONE_ID${NC}"
fi

# Step 2: Display nameservers for domain registrar update
echo ""
echo -e "${GREEN}Step 2: Nameservers to update at your domain registrar:${NC}"
echo -e "${CYAN}=======================================================${NC}"
aws route53 get-hosted-zone --id "$HOSTED_ZONE_ID" --query 'DelegationSet.NameServers[]' --output table
echo -e "${CYAN}=======================================================${NC}"
echo -e "${RED}⚠ IMPORTANT: Update these nameservers at your domain registrar (GoDaddy, Namecheap, etc.)${NC}"

# Step 3: Get App Runner service ARN
echo ""
echo -e "${GREEN}Step 3: Finding App Runner service...${NC}"
servicesJson=$(aws apprunner list-services --region "$REGION" --output json)
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Error: Failed to list App Runner services. Check AWS CLI configuration.${NC}"
    exit 1
fi

SERVICE_ARN=$(echo "$servicesJson" | jq -r ".ServiceSummaryList[] | select(.ServiceName==\"$SERVICE_NAME\") | .ServiceArn")

if [ -z "$SERVICE_ARN" ]; then
    echo -e "${RED}✗ Error: Service '$SERVICE_NAME' not found.${NC}"
    echo -e "${YELLOW}Available services:${NC}"
    echo "$servicesJson" | jq -r '.ServiceSummaryList[].ServiceName' | sed 's/^/  - /'
    exit 1
fi

echo -e "${GREEN}✓ Found service ARN: $SERVICE_ARN${NC}"

# Step 4: Associate custom domain with App Runner
echo ""
echo -e "${GREEN}Step 4: Associating custom domain with App Runner...${NC}"
aws apprunner associate-custom-domain --service-arn "$SERVICE_ARN" --domain-name "$DOMAIN" --region "$REGION" --output json > /dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Custom domain association initiated successfully!${NC}"
else
    echo -e "${RED}✗ Error: Failed to associate custom domain${NC}"
    exit 1
fi

# Step 5: Check initial status
echo ""
echo -e "${GREEN}Step 5: Checking domain validation status...${NC}"
domainStatus=$(aws apprunner describe-custom-domains --service-arn "$SERVICE_ARN" --region "$REGION" --query 'CustomDomains[0].Status' --output text)
echo -e "${YELLOW}Current status: $domainStatus${NC}"

# Final instructions
echo ""
echo -e "${CYAN}=== NEXT STEPS ===${NC}"
echo -e "${RED}1. ⚠ UPDATE NAMESERVERS at your domain registrar with the ones shown above${NC}"
echo -e "${YELLOW}2. ⏱ Wait 5-30 minutes for DNS propagation (can take up to 24-48 hours)${NC}"
echo -e "${GREEN}3. 🔍 Monitor status with this command:${NC}"
echo -e "${GRAY}   aws apprunner describe-custom-domains --service-arn \"$SERVICE_ARN\" --region $REGION --query 'CustomDomains[0].Status'${NC}"
echo ""
echo -e "${GREEN}Expected status progression:${NC}"
echo -e "${GRAY}  pending_certificate_dns_validation → pending_domain_dns_validation → active ✓${NC}"
echo ""
echo -e "${GREEN}4. 🚀 Once status is 'active', test your domain: https://$DOMAIN${NC}"

# Create monitoring script
cat > check_domain_status.sh << EOF
#!/bin/bash
# Quick status check script
aws apprunner describe-custom-domains --service-arn "$SERVICE_ARN" --region $REGION --query 'CustomDomains[0].Status' --output text
EOF

chmod +x check_domain_status.sh
echo ""
echo -e "${GREEN}✓ Created 'check_domain_status.sh' for easy status monitoring${NC}"
