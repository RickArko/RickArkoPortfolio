SHELL := bash

APP_NAME ?= rickarkoportfolio
SERVICE_NAME ?= RickArko_Portfolio
AWS_REGION ?= us-east-1
DOMAIN ?= rickarko.com
IMAGE_NAME ?= $(APP_NAME)
PORT ?= 8080

.PHONY: help install dev test format lint lint-shell verify docker-build docker-run ecr-setup domain-setup domain-status domain-debug

help: ## Show available targets
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "%-16s %s\n", $$1, $$2}'

install: ## Install project dependencies with uv
	uv sync --dev

dev: ## Run the Flask app locally on port 8080
	uv run src/app.py

test: ## Run the test suite
	uv run pytest

format: ## Format Python code with Ruff
	uv run ruff format src tests

lint: ## Lint Python code with Ruff
	uv run ruff check src tests

lint-shell: ## Lint shell scripts with shellcheck if installed
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck deployment/bin/*.sh deployment/*.sh ecr.sh; \
	else \
		echo "shellcheck not installed; skipping shell lint"; \
	fi

verify: test lint-shell ## Run the verification steps used in this repo

docker-build: ## Build the Docker image locally
	docker build -t $(IMAGE_NAME):latest .

docker-run: ## Run the Docker image locally
	docker run --rm -p $(PORT):8080 $(IMAGE_NAME):latest

ecr-setup: ## Build, tag, and push the image to ECR
	APP_NAME="$(APP_NAME)" AWS_REGION="$(AWS_REGION)" ./deployment/bin/ecr-setup.sh

domain-setup: ## Associate the App Runner custom domain and update Route 53
	DOMAIN="$(DOMAIN)" SERVICE_NAME="$(SERVICE_NAME)" AWS_REGION="$(AWS_REGION)" ./deployment/bin/apprunner-domain-setup.sh

domain-status: ## Show current App Runner and DNS status for the custom domain
	DOMAIN="$(DOMAIN)" SERVICE_NAME="$(SERVICE_NAME)" AWS_REGION="$(AWS_REGION)" ./deployment/bin/apprunner-domain-status.sh

domain-debug: ## Watch detailed custom-domain status output
	DOMAIN="$(DOMAIN)" SERVICE_NAME="$(SERVICE_NAME)" AWS_REGION="$(AWS_REGION)" ./deployment/bin/apprunner-debug.sh --watch
