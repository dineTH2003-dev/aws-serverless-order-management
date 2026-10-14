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
  description = "Map of Lambda function name to invoke ARN (used by API Gateway)"
  value = {
    for k, fn in aws_lambda_function.functions : k => fn.invoke_arn
  }
}

output "execution_role_arn" {
  description = "IAM execution role ARN shared by all Lambda functions"
  value       = aws_iam_role.lambda_exec.arn
}
