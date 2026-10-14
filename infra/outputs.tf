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

# ── Phase 1 outputs ───────────────────────────────────────────────────────────
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

# ── Placeholder outputs (uncommented as phases are completed) ─────────────────
# output "api_gateway_url" {
#   value = module.api_gateway.api_url   # Phase 4
# }
# output "cognito_user_pool_id" {
#   value = module.cognito.user_pool_id  # Phase 2
# }
