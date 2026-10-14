variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "api_gateway_name" {
  description = "API Gateway REST API name"
  type        = string
}

variable "lambda_function_names" {
  description = "Map of Lambda function names"
  type        = map(string)
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "waf_web_acl_name" {
  description = "WAF WebACL name"
  type        = string
}

variable "alert_email" {
  description = "Optional email address to receive SNS alert notifications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
