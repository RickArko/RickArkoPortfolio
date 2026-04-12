# Custom Domain Setup: rickarko.com → App Runner

## Current Configuration (Active)

| Record | Type | Target |
|--------|------|--------|
| `rickarko.com` | A (Alias) | `ctydyem9cj.us-east-1.awsapprunner.com` |
| `www.rickarko.com` | CNAME | `ctydyem9cj.us-east-1.awsapprunner.com` |
| `exactera.rickarko.com` | A (Alias) | `d2rlz3a5juewfl.cloudfront.net` |
| `tracker.rickarko.com` | CNAME | Cloudflare Tunnel |

- **Hosted Zone ID:** `Z08302203OZOEJNRETXLE`
- **Nameservers:** AWS Route 53 (migrated from GoDaddy)
- **SSL:** Managed by App Runner (ACM), auto-renewing
- **App Runner Hosted Zone (us-east-1):** `Z01915732ZBZKC8D32TPT`

---

## Verify Domain Health

```bash
# 1. Check App Runner custom domain status (should show "active")
aws apprunner describe-custom-domains \
  --service-arn "arn:aws:apprunner:us-east-1:$(aws sts get-caller-identity --query Account --output text):service/RickArko_Portfolio/c19016262e9e4c578b072cf6b09dd7d7" \
  --query "CustomDomains[*].{Domain:DomainName,Status:Status}" \
  --output table

# 2. Check DNS resolution
nslookup rickarko.com
nslookup www.rickarko.com

# 3. Check SSL certificate
curl -vI https://rickarko.com 2>&1 | grep -E "subject:|expire|HTTP/"

# 4. Test all routes respond 200
for path in "/" "/home/" "/experience/" "/projects/" "/blog/"; do
  echo "$path → $(curl -s -o /dev/null -w '%{http_code}' https://rickarko.com${path})"
done

# 5. List all Route 53 records
aws route53 list-resource-record-sets \
  --hosted-zone-id Z08302203OZOEJNRETXLE \
  --query "ResourceRecordSets[*].{Name:Name,Type:Type}" \
  --output table
```

---

## Reconnect Domain (If Broken)

If the domain stops working (e.g., certificate expires, association removed):

```bash
SERVICE_ARN="arn:aws:apprunner:us-east-1:$(aws sts get-caller-identity --query Account --output text):service/RickArko_Portfolio/c19016262e9e4c578b072cf6b09dd7d7"

# Step 1: Remove failed association (if any)
aws apprunner disassociate-custom-domain \
  --service-arn "$SERVICE_ARN" \
  --domain-name "rickarko.com"

# Wait ~15 seconds for disassociation
sleep 15

# Step 2: Re-associate domain
aws apprunner associate-custom-domain \
  --service-arn "$SERVICE_ARN" \
  --domain-name "rickarko.com" \
  --enable-www-subdomain

# Step 3: Get new certificate validation records
aws apprunner describe-custom-domains \
  --service-arn "$SERVICE_ARN" \
  --query "CustomDomains[0].CertificateValidationRecords[*].{Name:Name,Value:Value}" \
  --output table

# Step 4: Add each validation CNAME to Route 53
# Replace NAME and VALUE with output from step 3
aws route53 change-resource-record-sets \
  --hosted-zone-id Z08302203OZOEJNRETXLE \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "NAME",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "VALUE"}]
      }
    }]
  }'

# Step 5: Ensure apex A record points to App Runner
aws route53 change-resource-record-sets \
  --hosted-zone-id Z08302203OZOEJNRETXLE \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "rickarko.com.",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z01915732ZBZKC8D32TPT",
          "DNSName": "ctydyem9cj.us-east-1.awsapprunner.com",
          "EvaluateTargetHealth": true
        }
      }
    }]
  }'

# Step 6: Monitor until status is "active" (usually 5-15 min)
watch -n 30 "aws apprunner describe-custom-domains \
  --service-arn \"$SERVICE_ARN\" \
  --query 'CustomDomains[0].Status' --output text"
```

---

## Teardown Domain

```bash
SERVICE_ARN="arn:aws:apprunner:us-east-1:$(aws sts get-caller-identity --query Account --output text):service/RickArko_Portfolio/c19016262e9e4c578b072cf6b09dd7d7"

# Remove custom domain from App Runner
aws apprunner disassociate-custom-domain \
  --service-arn "$SERVICE_ARN" \
  --domain-name "rickarko.com"

# Delete hosted zone (removes all DNS records)
# WARNING: This affects ALL subdomains (exactera, tracker, etc.)
aws route53 delete-hosted-zone --id Z08302203OZOEJNRETXLE
```

---

## Cost

- **Route 53 hosted zone:** $0.50/month
- **DNS queries:** $0.40/million (first billion free)
- **SSL certificate:** Free (included with App Runner)
- **Custom domain association:** Free
