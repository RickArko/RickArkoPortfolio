# Rick Arko Portfolio Website
Personal portfolio website built with Flask showcasing ML projects and experience.

## 🚀 Quick Start

### Local Development (w/o Docker)
```bash
uv sync --dev
uv run src/app.py
```

### Docker
```bash
# Build and run
docker build -t rickarkoportfolio .
docker run -p 8080:8080 rickarkoportfolio
```

## 🌐 Deployment

### AWS App Runner (Recommended)
1. Push code to GitHub
2. Connect repository to AWS App Runner
3. App Runner automatically uses `apprunner.yaml` configuration
4. Automatic HTTPS and scaling included

### AWS EC2
1. Launch Ubuntu 22.04 instance
2. Install dependencies and clone repository
3. Use systemd service in `deployment/` folder
4. Configure nginx for reverse proxy

### AWS ECS/Fargate
1. Push Docker image to ECR
2. Use task definition in `deployment/ecs-task-definition.json`
3. Create ECS service with Application Load Balancer

## 📁 Project Structure
```
├── src/                # Flask application
├── deployment/         # Deployment configurations
├── Dockerfile          # Container configuration
├── apprunner.yaml      # AWS App Runner configuration
└── pyproject.toml      # Python dependencies
```
