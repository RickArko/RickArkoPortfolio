# Deploying to AWS App Runner

## Architecture

```
GitHub Repo → Docker Image → ECR → App Runner → rickarko.com
                                        ↑
                                   Route 53 DNS
                                   (Alias + CNAME)
```

- **Service:** `RickArko_Portfolio`
- **Region:** `us-east-1`
- **Port:** `8080`
- **Runtime:** Docker (python:3.10-slim + uv + gunicorn)
- **Live URL:** `https://ctydyem9cj.us-east-1.awsapprunner.com`
- **Custom Domain:** `https://rickarko.com` / `https://www.rickarko.com`

---

## Deploy a New Version

### 1. Build and push Docker image to ECR

```bash
# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Authenticate Docker to ECR
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Build, tag, and push
docker build -t rickarkoportfolio .
docker tag rickarkoportfolio:latest ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/rickarkoportfolio:latest
docker push ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/rickarkoportfolio:latest
```

### 2. Trigger App Runner deployment

If auto-deploy is enabled, the push triggers a new deployment automatically.
To deploy manually:

```bash
aws apprunner start-deployment \
  --service-arn "arn:aws:apprunner:us-east-1:${ACCOUNT_ID}:service/RickArko_Portfolio/c19016262e9e4c578b072cf6b09dd7d7"
```

---

## Verify Deployment

```bash
# Check service status
aws apprunner describe-service \
  --service-arn "arn:aws:apprunner:us-east-1:$(aws sts get-caller-identity --query Account --output text):service/RickArko_Portfolio/c19016262e9e4c578b072cf6b09dd7d7" \
  --query "Service.{Status:Status,Url:ServiceUrl,Updated:UpdatedAt}" \
  --output table

# Test the App Runner URL directly
curl -s -o /dev/null -w "%{http_code}" https://ctydyem9cj.us-east-1.awsapprunner.com

# Test the custom domain
curl -s -o /dev/null -w "%{http_code}" https://rickarko.com

# Test all routes
for path in "/" "/home/" "/experience/" "/projects/" "/blog/"; do
  echo "$path → $(curl -s -o /dev/null -w '%{http_code}' https://rickarko.com${path})"
done
```

---

## Create App Runner Service from Scratch

Only needed if the service doesn't exist yet:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws apprunner create-service \
  --service-name RickArko_Portfolio \
  --source-configuration "{
    \"ImageRepository\": {
      \"ImageIdentifier\": \"${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/rickarkoportfolio:latest\",
      \"ImageRepositoryType\": \"ECR\"
    },
    \"AutoDeploymentsEnabled\": true
  }" \
  --instance-configuration "{
    \"Cpu\": \"1 vCPU\",
    \"Memory\": \"2 GB\"
  }" \
  --network-configuration "{
    \"EgressConfiguration\": {\"EgressType\": \"DEFAULT\"}
  }" \
  --health-check-configuration "{
    \"Protocol\": \"HTTP\",
    \"Path\": \"/\",
    \"Interval\": 10,
    \"Timeout\": 5,
    \"HealthyThreshold\": 1,
    \"UnhealthyThreshold\": 5
  }"
```

---

## Cost

| Component | Monthly Cost |
|-----------|-------------|
| App Runner (idle, provisioned) | ~$5-7 |
| App Runner (active compute) | $0.064/vCPU-hr + $0.007/GB-hr |
| ECR storage | ~$0.10/GB |
| Route 53 hosted zone | $0.50 |
| SSL certificate | Free (included) |

Check actual spend:
```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "30 days ago" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY --metrics BlendedCost \
  --filter '{"Dimensions":{"Key":"SERVICE","Values":["AWS App Runner"]}}'
```
