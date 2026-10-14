output "api_id" {
  description = "The ID of the REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_arn" {
  description = "The ARN of the REST API"
  value       = aws_api_gateway_rest_api.main.arn
}

output "api_url" {
  description = "Base URL of the deployed API stage"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "stage_name" {
  description = "The name of the deployment stage"
  value       = aws_api_gateway_stage.main.stage_name
}

output "stage_arn" {
  description = "The ARN of the deployment stage (used for WAF WebACL association)"
  value       = aws_api_gateway_stage.main.arn
}

output "execution_arn" {
  description = "The execution ARN of the REST API"
  value       = aws_api_gateway_rest_api.main.execution_arn
}
