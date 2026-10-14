# Outputs are populated as modules are wired in subsequent phases

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

# output "api_gateway_url" {
#   description = "The base URL of the deployed API"
#   value       = module.api_gateway.api_url  # Phase 4
# }

# output "cognito_user_pool_id" {
#   description = "The Cognito User Pool ID"
#   value       = module.cognito.user_pool_id  # Phase 2
# }

# output "dynamodb_table_name" {
#   description = "The DynamoDB table name"
#   value       = module.dynamodb.table_name  # Phase 1
# }
