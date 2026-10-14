# AWS Serverless Order Management API

A production-grade, fully serverless Order Management REST API built on AWS. Part of Project 3 from the AWS Cloud Engineering portfolio guide.

## Architecture

```
Client (Mobile/Web)
    │
    ▼
[AWS WAF] ──── Security rules, rate limiting, OWASP protection
    │
    ▼
[Amazon API Gateway] ──── REST API endpoints, request validation, throttling
    │                  │
    │           [Amazon Cognito] ──── JWT authentication & authorization
    │
    ▼
[AWS Lambda] ──── Business logic (create/get/list/delete orders)
    │
    ▼
[Amazon DynamoDB] ──── Persistent NoSQL storage (On-Demand, encrypted)
```

## AWS Services

| Service | Purpose |
|---|---|
| **AWS Lambda** | Serverless compute — order processing logic |
| **Amazon API Gateway** | REST API — public entry point, routing, validation |
| **Amazon DynamoDB** | NoSQL database — order persistence |
| **Amazon Cognito** | Authentication — user management & JWT tokens |
| **AWS WAF** | Security — OWASP protection & rate limiting |
| **AWS X-Ray** | Distributed tracing — end-to-end observability |
| **Amazon CloudWatch** | Logging, metrics & alarms |

## Prerequisites

- AWS CLI v2 configured with `account2` profile
- Terraform >= 1.6.0
- Python 3.11+
- `pip-tools` for dependency management

## Quick Start

### 1. Clone & Install Dependencies
```bash
git clone https://github.com/dineTH2003-dev/aws-serverless-order-management.git
cd aws-serverless-order-management
python3 -m venv .venv && source .venv/bin/activate
make install
```

### 2. Configure Environment
```bash
cp .env.example .env
# Edit .env with your values
```

### 3. Deploy Infrastructure
```bash
make tf-init ENV=dev
make tf-plan ENV=dev
make tf-apply ENV=dev
```

### 4. Run Tests
```bash
make test-unit          # Unit tests (no AWS required)
make test-integration   # Integration tests (requires deployed env)
```

## API Reference

See [`docs/api-spec.yaml`](docs/api-spec.yaml) for the full OpenAPI 3.0 specification.

| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `POST` | `/orders` | Create a new order | Yes |
| `GET` | `/orders` | List orders for authenticated user | Yes |
| `GET` | `/orders/{orderId}` | Get a specific order | Yes |
| `DELETE` | `/orders/{orderId}` | Delete an order | Yes |

## Project Structure

```
├── .github/workflows/   # CI/CD pipelines
├── infra/               # Terraform IaC
│   └── modules/         # Reusable Terraform modules
├── src/
│   ├── orders/          # Lambda function handlers
│   └── shared/          # Shared utilities (models, db, exceptions)
├── tests/
│   ├── unit/            # Unit tests (moto mocked)
│   └── integration/     # Integration tests (live AWS)
├── docs/                # Architecture docs & API spec
└── scripts/             # Utility scripts
```

## Branch Strategy

Each feature/phase is developed on its own branch and merged via PR:
- `feat/phase-0-foundation` — Project scaffolding
- `feat/phase-1-dynamodb` — DynamoDB design & Terraform module
- `feat/phase-2-cognito` — Cognito authentication
- `feat/phase-3-lambda` — Lambda function implementations
- `feat/phase-4-api-gateway` — API Gateway configuration
- `feat/phase-5-waf` — WAF security rules
- `feat/phase-6-monitoring` — Observability & alerting
- `feat/phase-7-terraform` — Full IaC wiring
- `feat/phase-8-testing` — Test suite
- `feat/phase-9-cicd` — GitHub Actions CI/CD
- `feat/phase-10-docs` — Documentation polish

## Author

Built as a portfolio project demonstrating AWS serverless architecture best practices.

**AWS Account:** account2 (265283365424) | **Region:** us-east-1
