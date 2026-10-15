.PHONY: help install lint format test test-unit test-integration tf-init tf-plan tf-apply tf-destroy clean build

PYTHON := python3
PIP    := pip3
TF     := terraform
ENV    ?= dev

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Python
install: ## Install all dependencies into virtualenv
	$(PIP) install -r requirements-dev.txt
	pre-commit install

lint: ## Run linters (ruff + black check)
	ruff check src/ tests/
	black --check src/ tests/

format: ## Auto-format code
	black src/ tests/
	ruff check --fix src/ tests/

test: ## Run all tests with coverage
	pytest tests/ -v --cov=src --cov-report=term-missing --cov-report=xml

test-unit: ## Run unit tests only
	pytest tests/unit/ -v --cov=src --cov-report=term-missing

test-integration: ## Run integration tests (requires deployed AWS env)
	pytest tests/integration/ -v

security-scan: ## Run bandit + pip-audit
	bandit -r src/ -ll
	pip-audit -r requirements.txt

build: ## Package Lambda functions as zip files
	@mkdir -p dist
	@for func in create_order get_order list_orders delete_order; do \
		zip -j dist/$${func}.zip src/orders/$${func}.py src/shared/models.py src/shared/db.py src/shared/exceptions.py; \
	done

tf-init: ## Terraform init for ENV (default: dev)
	cd infra && $(TF) init -backend-config=environments/$(ENV)/backend.tfvars

tf-plan: ## Terraform plan for ENV
	cd infra && $(TF) plan -var-file=environments/$(ENV)/terraform.tfvars -out=tfplan

tf-apply: ## Terraform apply saved plan
	cd infra && $(TF) apply tfplan

tf-destroy: ## Destroy infrastructure for ENV
	cd infra && $(TF) destroy -var-file=environments/$(ENV)/terraform.tfvars

tf-validate: ## Validate and format-check Terraform
	cd infra && $(TF) fmt -check -recursive && $(TF) validate

clean: ## Remove build artifacts
	rm -rf dist/ .pytest_cache/ htmlcov/ coverage.xml .coverage *.zip
	find . -type d -name __pycache__ -exec rm -rf {} +
