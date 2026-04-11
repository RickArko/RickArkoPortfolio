# Custom Domain Setup for AWS Deployments

## AppRunner

### Overview
Complete guide to set up a custom domain for AWS App Runner service using Route 53 for DNS management.

### Prerequisites
- Domain registered with any provider (GoDaddy, Namecheap, etc.)
- AWS CLI configured with appropriate permissions
- App Runner service already deployed

### Timeline Expectations
- **Nameserver Update**: 5-30 minutes at domain registrar
- **DNS Propagation**: 5-30 minutes (can take up to 24-48 hours)
- **Certificate Validation**: 5-15 minutes after DNS propagation
- **Total Time**: Usually 30-60 minutes, maximum 48 hours

### Status Progression
Your domain will go through these stages:
1. `pending_certificate_dns_validation` - Waiting for DNS validation
2. `pending_domain_dns_validation` - Validating domain ownership  
3. `active` - Domain ready to use ✅

---

## Complete Setup Process

### Step 1: Configure Variables
Update these variables for your project in the setup script:

```powershell
$DOMAIN = "your-domain.com"           # Your custom domain
$SERVICE_NAME = "Your_Service_Name"   # Exact App Runner service name (case-sensitive)
$REGION = "us-east-1"                 # AWS region where your service runs
```

### Step 2: Run Complete Setup Script
```powershell
# PowerShell - Creates everything automatically
.\deployment\apprunner_custom_domain_complete.ps1
```

### Step 3: Update Domain Registrar Nameservers
The script outputs AWS nameservers. In your domain registrar (GoDaddy, Namecheap, etc.):

1. **Login** to your domain registrar
2. **Find** your domain management page  
3. **Change nameservers** from "Default" to "Custom"
4. **Replace** existing nameservers with the 4 AWS nameservers provided
5. **Save** changes

Example AWS nameservers:
- `ns-770.awsdns-32.net`
- `ns-1794.awsdns-32.co.uk` 
- `ns-1234.awsdns-26.org`
- `ns-343.awsdns-42.com`

### Step 4: Monitor and Validate
```powershell
# Check nameserver propagation (should show AWS nameservers)
nslookup -type=NS your-domain.com

# Check App Runner validation status
aws apprunner describe-custom-domains --service-arn "YOUR_SERVICE_ARN" --region YOUR_REGION --query 'CustomDomains[0].Status'

# Test domain (once active)
Test-NetConnection your-domain.com -Port 443
```

### Step 5: Verify Working Domain
Once status shows `"active"`:
- Visit `https://your-domain.com` 
- SSL certificate automatically managed by AWS

---

## Key Technical Details

### What the Script Does Automatically:
1. **Creates Route 53 hosted zone** for your domain
2. **Associates custom domain** with App Runner service
3. **Creates CNAME record** pointing domain → App Runner service URL
4. **Handles certificate validation** records if needed
5. **Provides monitoring commands** for status tracking

### DNS Records Created:
- **NS Records**: Point to AWS nameservers
- **SOA Record**: Start of Authority for the zone
- **CNAME Record**: `your-domain.com` → `your-service.region.awsapprunner.com`
- **Validation Records**: For SSL certificate (automatically managed)

---

## Troubleshooting Guide

### Domain Stuck in `pending_certificate_dns_validation`
**Cause**: Nameservers not updated or DNS not propagated  
**Solution**: 
- Verify nameserver change at domain registrar
- Wait 30-60 minutes for propagation
- Check with: `nslookup -type=NS your-domain.com`

### Domain Not Resolving After Status is "Active"
**Cause**: Missing DNS records in Route 53  
**Solution**: Run the debugging script to check and fix DNS records

### Service ARN Not Found
**Cause**: Incorrect service name or region  
**Solution**: 
- List services: `aws apprunner list-services --region YOUR_REGION`
- Verify exact service name (case-sensitive)

### Permission Errors
**Required AWS Permissions**:
- `apprunner:AssociateCustomDomain`
- `apprunner:DescribeCustomDomains` 
- `apprunner:DescribeService`
- `route53:CreateHostedZone`
- `route53:ChangeResourceRecordSets`
- `route53:ListResourceRecordSets`

---

## Alternative: Manual Setup (AWS Console)
If automated scripts don't work:

1. **Route 53 Console**: Create hosted zone for your domain
2. **App Runner Console**: Your service → Custom domains → Add domain  
3. **Follow validation prompts** in the console
4. **Update nameservers** at your domain registrar
5. **Add any required DNS records** manually

---

## Cost Breakdown
- **Route 53 Hosted Zone**: $0.50/month per domain
- **DNS Queries**: $0.40 per million queries (first billion free)
- **App Runner Custom Domain**: No additional cost
- **SSL Certificate**: Included free with App Runner

---

## For Multiple Sites
- Use the same scripts with different domain/service variables
- Each domain needs its own hosted zone ($0.50/month each)
- Nameserver process is the same for each domain registrar
