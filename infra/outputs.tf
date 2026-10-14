output "project_name" {
  description = "The project name"
  value       = var.project_name
}

output "environment" {
  description = "The deployment environment"
  value       = var.environment
}

output "aws_region" {
  description = "The AWS region"
  value       = var.aws_region
}

# ── Phase 1: DynamoDB ─────────────────────────────────────────────────────────
output "dynamodb_table_name" {
  description = "DynamoDB orders table name"
  value       = module.dynamodb.table_name
}

output "dynamodb_table_arn" {
  description = "DynamoDB orders table ARN"
  value       = module.dynamodb.table_arn
}

output "dynamodb_kms_key_arn" {
  description = "KMS key ARN for DynamoDB encryption"
  value       = module.dynamodb.kms_key_arn
}

# ── Phase 2: Cognito ──────────────────────────────────────────────────────────
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.cognito.user_pool_id
}

output "cognito_app_client_id" {
  description = "Cognito App Client ID"
  value       = module.cognito.app_client_id
}

output "cognito_jwks_uri" {
  description = "JWKS URI for JWT validation"
  value       = module.cognito.jwks_uri
}

# ── Phase 3: Lambda ───────────────────────────────────────────────────────────
output "lambda_function_arns" {
  description = "Map of Lambda function ARNs"
  value       = module.lambda.function_arns
}

output "lambda_function_names" {
  description = "Map of Lambda function names"
  value       = module.lambda.function_names
}

# ── Placeholder: Phase 4 ──────────────────────────────────────────────────────
# output "api_gateway_url" {
#   value = module.api_gateway.api_url
# }
