variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN for authorizer"
  type        = string
}

variable "lambda_invoke_arns" {
  description = "Map of Lambda function names to invoke ARNs"
  type        = map(string)
}

variable "lambda_function_names" {
  description = "Map of Lambda function names (for lambda permissions)"
  type        = map(string)
}

variable "throttling_burst_limit" {
  description = "API Gateway throttling burst limit"
  type        = number
  default     = 1000
}

variable "throttling_rate_limit" {
  description = "API Gateway steady-state request rate limit (requests per second)"
  type        = number
  default     = 500
}

variable "tags" {
  description = "Additional tags to apply"
  type        = map(string)
  default     = {}
}
