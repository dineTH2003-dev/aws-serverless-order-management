variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name to grant Lambda access to"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "DynamoDB table ARN for IAM policy"
  type        = string
}

variable "dynamodb_kms_key_arn" {
  description = "KMS key ARN used for DynamoDB — needed for Lambda to decrypt"
  type        = string
}

variable "log_level" {
  description = "Log level for Lambda functions (DEBUG, INFO, WARNING, ERROR)"
  type        = string
  default     = "INFO"
}

variable "lambda_memory_mb" {
  description = "Memory (MB) allocated to each Lambda function"
  type        = number
  default     = 256
}

variable "lambda_timeout_seconds" {
  description = "Timeout in seconds for each Lambda function"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
