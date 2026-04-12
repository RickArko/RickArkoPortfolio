# AWS App Runner Deployment Architecture

## Current Deployed Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub Repo   │───▶│  Local Docker   │───▶│   Amazon ECR    │
│ RickArkoPortfolio│    │     Build       │    │   Repository    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    AWS App Runner Service                       │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   Load Balancer │  │  Container(s)   │  │   Auto Scaling  │ │
│  │   + HTTPS/TLS   │  │  Flask + uv +   │  │   (Managed)     │ │
│  │                 │  │  Gunicorn       │  │                 │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
                    ┌─────────────────┐
                    │  Public URL     │
                    │ ctydyem9cj...   │
                    │ awsapprunner... │
                    └─────────────────┘
```

## AWS Resources Created

### 1. Amazon ECR (Elastic Container Registry)
- **Purpose:** Stores your Docker images securely
- **Resource:** `122610507380.dkr.ecr.us-east-1.amazonaws.com/rickarko_portfolio`
- **Shared:** ❌ Each app needs its own repository
- **Script:** [`ecr-setup.sh`](../deployment/ecr-setup.sh)

```bash
# Create ECR Repository
aws ecr create-repository --repository-name rickarko_portfolio --region us-east-1
```

### 2. AWS App Runner Service
- **Purpose:** Runs your containerized Flask application with auto-scaling
- **Resource:** `rickarkoportfolio` service
- **URL:** `https://ctydyem9cj.us-east-1.awsapprunner.com/`
- **Shared:** ❌ Each app needs its own service
- **Script:** [`apprunner-create.sh`](../deployment/apprunner-create.sh)

```bash
# Create App Runner Service
aws apprunner create-service \
  --service-name rickarkoportfolio \
  --source-configuration '{
    "ImageRepository": {
      "ImageIdentifier": "122610507380.dkr.ecr.us-east-1.amazonaws.com/rickarko_portfolio:latest",
      "ImageRepositoryType": "ECR"
    },
    "AutoDeploymentsEnabled": true
  }' \
  --instance-configuration '{
    "Cpu": "1 vCPU",
    "Memory": "2 GB"
  }' \
  --region us-east-1
```

### 3. IAM Roles (Auto-Created)
- **Purpose:** Allows App Runner to pull images from ECR
- **Resource:** `AppRunnerECRAccessRole` (auto-generated)
- **Shared:** ✅ Can be reused across App Runner services

### 4. Application Load Balancer (Managed)
- **Purpose:** Routes traffic, handles HTTPS/TLS certificates
- **Resource:** Managed by App Runner (not visible in console)
- **Shared:** ❌ Each App Runner service gets its own

## Complete Deployment Process

### Phase 1: Build & Push Container

1. **Build Docker Image Locally**
   ```bash
   docker build -t rickarko_portfolio:latest .
   ```

2. **Tag for ECR**
   ```bash
   docker tag rickarko_portfolio:latest 122610507380.dkr.ecr.us-east-1.amazonaws.com/rickarko_portfolio:latest
   ```

3. **Push to ECR**
   ```bash
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 122610507380.dkr.ecr.us-east-1.amazonaws.com
   docker push 122610507380.dkr.ecr.us-east-1.amazonaws.com/rickarko_portfolio:latest
   ```

### Phase 2: Deploy to App Runner

4. **Create App Runner Service**
   - Uses ECR image as source
   - Auto-configures load balancer, HTTPS, scaling
   - Assigns random public URL

## Template for New Flask Apps

### Per-App Resources (Not Shared)
- ✅ **ECR Repository:** `your-app-name`
- ✅ **App Runner Service:** `your-app-service`
- ✅ **Public URL:** `https://random.us-east-1.awsapprunner.com/`

### Shared Resources
- ✅ **AWS Account/Region:** Same account, recommend same region
- ✅ **IAM Roles:** App Runner will reuse ECR access role
- ❌ **Load Balancers:** Each service gets its own (managed)

### Deployment Template Script

```bash
#!/bin/bash
# deploy-flask-app.sh

APP_NAME=$1
if [ -z "$APP_NAME" ]; then
  echo "Usage: ./deploy-flask-app.sh <app-name>"
  exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
AWS_REGION="us-east-1"
ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME"

# 1. Create ECR Repository
aws ecr create-repository --repository-name $APP_NAME --region $AWS_REGION

# 2. Build and Push
docker build -t $APP_NAME:latest .
docker tag $APP_NAME:latest $ECR_URI:latest
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
docker push $ECR_URI:latest

# 3. Create App Runner Service
aws apprunner create-service \
  --service-name $APP_NAME \
  --source-configuration "{
    \"ImageRepository\": {
      \"ImageIdentifier\": \"$ECR_URI:latest\",
      \"ImageRepositoryType\": \"ECR\"
    },
    \"AutoDeploymentsEnabled\": true
  }" \
  --instance-configuration '{
    "Cpu": "1 vCPU",
    "Memory": "2 GB"
  }' \
  --region $AWS_REGION

echo "Deployment initiated for $APP_NAME"
echo "Check App Runner console for service URL"
```

## Custom Domain Setup (Optional)

### To Get a Static URL:

1. **Register/Import Domain in Route 53**
2. **Create Custom Domain in App Runner:**
   ```bash
   aws apprunner associate-custom-domain \
     --service-arn arn:aws:apprunner:us-east-1:122610507380:service/rickarkoportfolio \
     --domain-name portfolio.yourdomain.com
   ```
3. **Update DNS Records** (App Runner provides CNAME targets)

### Additional AWS Resources for Custom Domain:
- ✅ **Route 53 Hosted Zone:** Can be shared across apps
- ✅ **ACM Certificate:** One per domain/subdomain
- ✅ **Custom Domain Association:** Per App Runner service

## Cost Optimization

### Shared Resources (Cost Efficient):
- **Route 53 Hosted Zone:** $0.50/month (shared across all subdomains)
- **ECR Storage:** Pay per GB stored (can clean up old images)

### Per-App Costs:
- **App Runner:** ~$7-30/month per service (based on usage)
- **Data Transfer:** Standard AWS rates

### Recommendations:
- Use subdomains: `app1.yourdomain.com`, `app2.yourdomain.com`
- Clean up unused ECR images regularly
- Monitor App Runner usage and scale appropriately

## Scripts Directory Structure

```
deployment/
├── DeploymentDiagram.md          # This file
├── AppRunner.md                  # Original deployment guide
└── scripts/
    ├── ecr-setup.sh             # Create ECR repository
    ├── apprunner-create.sh      # Create App Runner service
    ├── deploy-flask-app.sh      # Complete deployment template
    └── cleanup.sh