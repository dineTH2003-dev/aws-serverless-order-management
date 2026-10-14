terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
      Repository  = "aws-serverless-order-management"
    }
  }
}

# ── Phase 1: DynamoDB ─────────────────────────────────────────────────────────
module "dynamodb" {
  source = "./modules/dynamodb"

  project_name  = var.project_name
  environment   = var.environment
  billing_mode  = "PAY_PER_REQUEST"
  enable_pitr   = true
  ttl_attribute = "ttl"
}

# ── Phase 2: Cognito ──────────────────────────────────────────────────────────
module "cognito" {
  source = "./modules/cognito"

  project_name                = var.project_name
  environment                 = var.environment
  mfa_configuration           = "OPTIONAL"
  access_token_validity_hours = 1
  refresh_token_validity_days = 30
}

# ── Phase 3: Lambda ───────────────────────────────────────────────────────────
# module "lambda" {
#   source = "./modules/lambda"
#   ...  implemented in feat/phase-3-lambda
# }

# ── Phase 4: API Gateway ──────────────────────────────────────────────────────
# module "api_gateway" {
#   source = "./modules/api_gateway"
#   ...  implemented in feat/phase-4-api-gateway
# }

# ── Phase 5: WAF ──────────────────────────────────────────────────────────────
# module "waf" {
#   source = "./modules/waf"
#   ...  implemented in feat/phase-5-waf
# }
