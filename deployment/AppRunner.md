# Deploying to AWS App Runner Using Docker & ECR

## 1. Build and Tag Your Docker Image

```bash
docker build -t rickarkoportfolio .
docker tag rickarkoportfolio:latest 122610507380.dkr.ecr.us-east-1.amazonaws.com/rickarkoportfolio:latest
```

## 2. Authenticate Docker to ECR

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 122610507380.dkr.ecr.us-east-1.amazonaws.com
```

## 3. Push Your Image to ECR

```bash
docker push 122610507380.dkr.ecr.us-east-1.amazonaws.com/rickarkoportfolio:latest
```

## 4. Create App Runner Service from ECR

1. Go to AWS Console → App Runner → Create Service.
2. Select **"Container registry"** as the source.
3. Choose **Amazon ECR** and select your image:  
   `122610507380.dkr.ecr.us-east-1.amazonaws.com/rickarkoportfolio:latest`
4. Set **port** to `8080`.
5. Add environment variable:  
   - Name: `FLASK_ENV`  
   - Value: `production`
6. Click **Create & Deploy**.

---

**Note:**  
- You do **not** need `apprunner.yaml` for Docker/ECR deployments.
- App Runner uses your Dockerfile’s `EXPOSE` and


aws apprunner create-service \
  --service-name rickarkoportfolio \
  --source-configuration '{
    "ImageRepository": {
      "ImageIdentifier": "122610507380.dkr.ecr.us-east-1.amazonaws.com/rickarkoportfolio:latest",
      "ImageRepositoryType": "ECR"
    },
    "AutoDeploymentsEnabled": true
  }' \
  --instance-configuration '{
    "Cpu": "1 vCPU",
    "Memory": "2 GB",
    "EnvironmentVariables": [
      {"Name": "FLASK_ENV", "Value": "production"}
    ]
  }' \
  --port 8080