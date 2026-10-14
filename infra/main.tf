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

# ─── Modules (wired in subsequent phases) ─────────────────────────────────────

# module "dynamodb" {
#   source = "./modules/dynamodb"
#   ...  # Phase 1
# }

# module "cognito" {
#   source = "./modules/cognito"
#   ...  # Phase 2
# }

# module "lambda" {
#   source = "./modules/lambda"
#   ...  # Phase 3
# }

# module "api_gateway" {
#   source = "./modules/api_gateway"
#   ...  # Phase 4
# }

# module "waf" {
#   source = "./modules/waf"
#   ...  # Phase 5
# }
