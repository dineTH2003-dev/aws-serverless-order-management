output "table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.orders.name
}

output "table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.orders.arn
}

output "table_stream_arn" {
  description = "DynamoDB table stream ARN (if enabled)"
  value       = aws_dynamodb_table.orders.stream_arn
}

output "kms_key_arn" {
  description = "KMS key ARN used for DynamoDB encryption"
  value       = aws_kms_key.dynamodb.arn
}

output "gsi_user_index_name" {
  description = "Name of the userId-createdAt GSI"
  value       = "userId-createdAt-index"
}

output "gsi_status_index_name" {
  description = "Name of the status-createdAt GSI"
  value       = "status-createdAt-index"
}
