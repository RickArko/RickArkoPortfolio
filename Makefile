SHELL := bash

APP_NAME ?= rickarko_portfolio
SERVICE_NAME ?= RickArko_Portfolio
AWS_REGION ?= us-east-1
DOMAIN ?= rickarko.com
IMAGE_NAME ?= $(APP_NAME)
PORT ?= 8080

BASE_URL ?= https://$(DOMAIN)

.PHONY: help install dev test test-fast test-unit test-integration test-e2e test-regression format format-check lint check lint-shell verify doctor-aws deploy-check docker-build docker-run ecr-setup domain-setup domain-status domain-debug ship smoke-test rollback preview-create preview-destroy pre-commit pre-commit-update

help: ## Show available targets
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "%-16s %s\n", $$1, $$2}'

install: ## Install project dependencies and pre-commit git hooks
	uv sync --dev
	uv run pre-commit install --install-hooks

pre-commit: ## Run pre-commit on all files (mirrors per-commit checks)
	uv run pre-commit run --all-files

pre-commit-update: ## Update pinned pre-commit hook versions
	uv run pre-commit autoupdate

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
		shellcheck -x --severity=warning deployment/bin/*.sh deployment/*.sh ecr.sh; \
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

ship: deploy-check ## Push current branch and open a PR into main
	@git push -u origin HEAD
	@gh pr create --fill --base main

smoke-test: ## Run the post-deploy HTTP contract smoke test (override BASE_URL=...)
	./deployment/bin/smoke-test.sh "$(BASE_URL)"

rollback: ## Restore a previous image to prod: make rollback DIGEST=sha256:...
	@test -n "$(DIGEST)" || { echo "Usage: make rollback DIGEST=sha256:..." >&2; exit 2; }
	APPRUNNER_SERVICE_ARN="$(APPRUNNER_SERVICE_ARN)" AWS_REGION="$(AWS_REGION)" ECR_REPOSITORY="$(APP_NAME)" BASE_URL="$(BASE_URL)" \
		./deployment/bin/rollback.sh --to "$(DIGEST)"

preview-create: ## Create a preview service for the current PR: make preview-create TAG=pr-123
	@pr="$$(gh pr view --json number -q .number)"; tag="$${TAG:-pr-$${pr}}"; \
		APPRUNNER_ACCESS_ROLE_ARN="$(APPRUNNER_ACCESS_ROLE_ARN)" AWS_REGION="$(AWS_REGION)" ECR_REPOSITORY="$(APP_NAME)" \
		./deployment/bin/preview-create.sh "$$pr" "$$tag"

preview-destroy: ## Tear down the preview service for the current PR
	@pr="$$(gh pr view --json number -q .number)"; \
		AWS_REGION="$(AWS_REGION)" ./deployment/bin/preview-destroy.sh "$$pr"
