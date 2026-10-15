output "function_arns" {
  description = "Map of Lambda function name to ARN"
  value = {
    for k, fn in aws_lambda_function.functions : k => fn.arn
  }
}

output "function_names" {
  description = "Map of Lambda function name to function name string"
  value = {
    for k, fn in aws_lambda_function.functions : k => fn.function_name
  }
}

output "function_invoke_arns" {
  description = "Map of Lambda function name to live alias invoke ARN (used by API Gateway)"
  value = {
    for k, alias in aws_lambda_alias.live : k => alias.invoke_arn
  }
}

output "function_alias_arns" {
  description = "Map of Lambda function name to live alias ARN"
  value = {
    for k, alias in aws_lambda_alias.live : k => alias.arn
  }
}

output "execution_role_arns" {
  description = "Map of function name to dedicated IAM execution role ARN"
  value = {
    for k, role in aws_iam_role.function_roles : k => role.arn
  }
}

output "execution_role_arn" {
  description = "Primary execution role ARN (maintained for backwards compatibility)"
  value       = aws_iam_role.function_roles["create_order"].arn
}
