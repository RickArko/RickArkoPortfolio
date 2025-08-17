# Website
Personal website built with Flask.

## 1. Docker
```
docker build --pull --rm -f "Dockerfile" -t "rickarkoportfolio:latest" "."
docker run -p 8080:8080 rickarkoportfolio:latest
```

## 2. Dev mode (without docker)
```
  uv sync --dev
  uv run src/app.py
```
