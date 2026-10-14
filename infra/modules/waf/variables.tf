variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "api_gateway_stage_arn" {
  description = "ARN of the API Gateway stage to associate with WAF"
  type        = string
}

variable "rate_limit_per_5min" {
  description = "Maximum requests allowed per IP in a 5-minute window"
  type        = number
  default     = 2000
}

variable "tags" {
  description = "Additional tags to apply to WAF resources"
  type        = map(string)
  default     = {}
}
