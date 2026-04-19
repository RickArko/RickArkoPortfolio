SHELL := bash

APP_NAME ?= rickarko_portfolio
SERVICE_NAME ?= RickArko_Portfolio
AWS_REGION ?= us-east-1
DOMAIN ?= rickarko.com
IMAGE_NAME ?= $(APP_NAME)
PORT ?= 8080

.PHONY: help install dev test test-fast test-unit test-integration test-e2e test-regression format format-check lint check lint-shell verify doctor-aws deploy-check docker-build docker-run ecr-setup domain-setup domain-status domain-debug

help: ## Show available targets
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "%-16s %s\n", $$1, $$2}'

install: ## Install project dependencies with uv
	uv sync --dev

dev: ## Run the Flask app locally on port 8080
	uv run python -m rickarko_portfolio

test: ## Run the full test suite with coverage
	uv run pytest --cov=rickarko_portfolio --cov-report=term-missing --cov-fail-under=90

test-fast: ## Run the fast feedback test suite
	uv run pytest -m "not end_to_end and not regression"

test-unit: ## Run unit tests only
	uv run pytest -m unit

test-integration: ## Run integration tests only
	uv run pytest -m integration

test-e2e: ## Run HTTP-first end-to-end tests only
	uv run pytest -m end_to_end

test-regression: ## Run regression tests only
	uv run pytest -m regression

format: ## Format Python code with Ruff
	uv run ruff format src tests

format-check: ## Check Python formatting with Ruff
	uv run ruff format --check src tests

lint: ## Lint Python code with Ruff
	uv run ruff check src tests

check: lint format-check test-fast ## Run the fast local quality gate

lint-shell: ## Lint shell scripts with shellcheck if installed
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -x deployment/bin/*.sh deployment/*.sh ecr.sh; \
	else \
		echo "shellcheck not installed; skipping shell lint"; \
	fi

verify: lint format-check test lint-shell ## Run the full verification steps used in this repo

doctor-aws: ## Validate local AWS auth, ECR, App Runner, and domain wiring
	APP_NAME="$(APP_NAME)" SERVICE_NAME="$(SERVICE_NAME)" AWS_REGION="$(AWS_REGION)" DOMAIN="$(DOMAIN)" ./deployment/bin/aws-doctor.sh

deploy-check: check ## Run local deployment readiness checks without pushing or deploying
	APP_NAME="$(APP_NAME)" SERVICE_NAME="$(SERVICE_NAME)" AWS_REGION="$(AWS_REGION)" DOMAIN="$(DOMAIN)" ./deployment/bin/deploy-check.sh

docker-build: ## Build the Docker image locally
	docker build -t $(IMAGE_NAME):latest .

docker-run: docker-build ## Build (if needed) and run the Docker image locally
	docker run --rm -p $(PORT):8080 $(IMAGE_NAME):latest

ecr-setup: ## Build, tag, and push the image to ECR
	APP_NAME="$(APP_NAME)" AWS_REGION="$(AWS_REGION)" ./deployment/bin/ecr-setup.sh

domain-setup: ## Associate the App Runner custom domain and update Route 53
	DOMAIN="$(DOMAIN)" SERVICE_NAME="$(SERVICE_NAME)" AWS_REGION="$(AWS_REGION)" ./deployment/bin/apprunner-domain-setup.sh

domain-status: ## Show current App Runner and DNS status for the custom domain
	DOMAIN="$(DOMAIN)" SERVICE_NAME="$(SERVICE_NAME)" AWS_REGION="$(AWS_REGION)" ./deployment/bin/apprunner-domain-status.sh

domain-debug: ## Watch detailed custom-domain status output
	DOMAIN="$(DOMAIN)" SERVICE_NAME="$(SERVICE_NAME)" AWS_REGION="$(AWS_REGION)" ./deployment/bin/apprunner-debug.sh --watch
