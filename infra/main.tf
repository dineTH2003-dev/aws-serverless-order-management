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
  profile = var.aws_profile != "" ? var.aws_profile : null

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
module "lambda" {
  source = "./modules/lambda"

  project_name           = var.project_name
  environment            = var.environment
  dynamodb_table_name    = module.dynamodb.table_name
  dynamodb_table_arn     = module.dynamodb.table_arn
  dynamodb_kms_key_arn   = module.dynamodb.kms_key_arn
  log_level              = var.log_level
  lambda_memory_mb       = 256
  lambda_timeout_seconds = 10
}

# ── Phase 4: API Gateway ──────────────────────────────────────────────────────
module "api_gateway" {
  source = "./modules/api_gateway"

  project_name           = var.project_name
  environment            = var.environment
  cognito_user_pool_arn  = module.cognito.user_pool_arn
  lambda_invoke_arns     = module.lambda.function_invoke_arns
  lambda_function_names  = module.lambda.function_names
  throttling_burst_limit = 1000
  throttling_rate_limit  = 500
}

# ── Phase 5: WAF ──────────────────────────────────────────────────────────────
module "waf" {
  source = "./modules/waf"

  project_name          = var.project_name
  environment           = var.environment
  api_gateway_stage_arn = module.api_gateway.stage_arn
  rate_limit_per_5min   = 2000
}

# ── Phase 6: Monitoring & Observability ───────────────────────────────────────
module "monitoring" {
  source = "./modules/monitoring"

  project_name          = var.project_name
  environment           = var.environment
  api_gateway_name      = "${var.project_name}-api-${var.environment}"
  lambda_function_names = module.lambda.function_names
  dynamodb_table_name   = module.dynamodb.table_name
  waf_web_acl_name      = "${var.project_name}-web-acl-${var.environment}"
}
