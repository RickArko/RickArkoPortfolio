# Deployment Runbook -- rickarko.com

Primary target: **AWS App Runner** (ECR image source).
CI/CD: GitHub Actions (test, build, push to ECR, trigger deploy).

---

## 1. Prerequisites

| Tool | Install |
|------|---------|
| AWS CLI v2 | `brew install awscli` or [docs](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| Docker | `brew install --cask docker` or [docs](https://docs.docker.com/get-docker/) |
| GitHub CLI | `brew install gh` |

### Required GitHub Secrets

Set in **Settings > Secrets and variables > Actions**:

```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION            # e.g. us-east-1
ECR_REPOSITORY        # e.g. rickarkoportfolio
APPRUNNER_SERVICE_ARN # e.g. arn:aws:apprunner:us-east-1:123456789012:service/rickarkoportfolio/...
```

---

## 2. First Deploy (Manual)

### 2a. Create ECR Repository

```bash
aws ecr create-repository --repository-name rickarkoportfolio

# capture identifiers
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
AWS_REGION=us-east-1
ECR_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/rickarkoportfolio
```

### 2b. Build and Push Image

```bash
# authenticate Docker to ECR
aws ecr get-login-password --region $AWS_REGION \
  | docker login --username AWS --password-stdin \
    $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# build
docker build -t rickarkoportfolio:latest .

# tag and push
docker tag rickarkoportfolio:latest $ECR_URI:latest
docker push $ECR_URI:latest
```

### 2c. Create App Runner Service

```bash
aws apprunner create-service \
  --service-name rickarkoportfolio \
  --source-configuration '{
    "AuthenticationConfiguration": {
      "AccessRoleArn": "arn:aws:iam::'$AWS_ACCOUNT_ID':role/AppRunnerECRAccess"
    },
    "AutoDeploymentsEnabled": false,
    "ImageRepository": {
      "ImageIdentifier": "'$ECR_URI':latest",
      "ImageRepositoryType": "ECR",
      "ImageConfiguration": {
        "Port": "8080",
        "RuntimeEnvironmentVariables": {
          "FLASK_ENV": "production"
        }
      }
    }
  }' \
  --instance-configuration '{
    "Cpu": "1024",
    "Memory": "2048"
  }' \
  --health-check-configuration '{
    "Protocol": "HTTP",
    "Path": "/health",
    "Interval": 10,
    "Timeout": 5,
    "HealthyThreshold": 1,
    "UnhealthyThreshold": 5
  }'
```

Save the returned `ServiceArn` -- that becomes the `APPRUNNER_SERVICE_ARN` GitHub secret.

### 2d. Associate Custom Domain

```bash
aws apprunner associate-custom-domain \
  --service-arn $APPRUNNER_SERVICE_ARN \
  --domain-name rickarko.com \
  --enable-www-subdomain
```

This returns CNAME validation records. Add them in step 3 below.

---

## 3. DNS Setup

### Option A: Route 53

```bash
# get the App Runner service URL (e.g. abc123.us-east-1.awsapprunner.com)
APP_RUNNER_URL=$(aws apprunner describe-service \
  --service-arn $APPRUNNER_SERVICE_ARN \
  --query 'Service.ServiceUrl' --output text)

# get hosted zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name rickarko.com \
  --query 'HostedZones[0].Id' --output text)

# create CNAME record
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "rickarko.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "'$APP_RUNNER_URL'"}]
      }
    }]
  }'
```

Also add the CNAME validation records returned by `associate-custom-domain`.

### Option B: External Registrar

Add these DNS records in your registrar's control panel:

| Type  | Name          | Value                                  | TTL |
|-------|---------------|----------------------------------------|-----|
| CNAME | rickarko.com  | `$APP_RUNNER_URL`                      | 300 |
| CNAME | (validation)  | (from `associate-custom-domain` output)| 300 |

---

## 4. TLS

### App Runner (primary)

No manual certificate management required. App Runner provisions and renews TLS certificates automatically via AWS Certificate Manager (ACM) when a custom domain is associated.

Verify domain status:

```bash
aws apprunner describe-custom-domains \
  --service-arn $APPRUNNER_SERVICE_ARN
```

Status should show `ACTIVE` once DNS validation completes.

### EC2/Nginx Fallback

If running on a standalone EC2 instance with the nginx config in `deployment/nginx/`:

```bash
# install certbot
sudo apt install certbot python3-certbot-nginx

# obtain cert
sudo certbot --nginx -d rickarko.com

# auto-renewal is configured via systemd timer; verify:
sudo systemctl status certbot.timer
```

Update `deployment/nginx/rarko-portfolio.conf` to point at the Let's Encrypt cert paths.

---

## 5. Subsequent Deploys

### Automatic (push to main)

```bash
git push origin main
# GitHub Actions pipeline: test -> build -> push ECR -> deploy App Runner
```

### Manual Trigger

```bash
gh workflow run deploy.yml --ref main
```

### Monitor Pipeline

```bash
gh run list --workflow=deploy.yml --limit 5
gh run view <run-id>
```

---

## 6. Rollback

### Revert to Previous App Runner Revision

```bash
# list recent operations
aws apprunner list-operations \
  --service-arn $APPRUNNER_SERVICE_ARN

# App Runner keeps previous revisions; re-push a known-good image tag:
docker pull $ECR_URI:<known-good-sha>
docker tag $ECR_URI:<known-good-sha> $ECR_URI:latest
docker push $ECR_URI:latest

aws apprunner start-deployment \
  --service-arn $APPRUNNER_SERVICE_ARN
```

### Git-Level Rollback

```bash
# revert the bad commit on main, which triggers a fresh deploy
git revert HEAD --no-edit
git push origin main
```

---

## 7. Monitoring

### Health Check

```bash
curl -sf https://rickarko.com/health && echo "OK" || echo "FAIL"
```

### App Runner Logs

```bash
aws apprunner list-operations \
  --service-arn $APPRUNNER_SERVICE_ARN \
  --query 'OperationSummaryList[0:5]'
```

### CloudWatch

App Runner streams stdout/stderr to CloudWatch Logs automatically.

```bash
# list log groups for App Runner
aws logs describe-log-groups \
  --log-group-name-prefix /aws/apprunner/rickarkoportfolio

# tail recent logs
aws logs tail /aws/apprunner/rickarkoportfolio/service --since 1h --follow
```

### Quick Status Check

```bash
aws apprunner describe-service \
  --service-arn $APPRUNNER_SERVICE_ARN \
  --query 'Service.{Status:Status,URL:ServiceUrl,Updated:UpdatedAt}'
```
