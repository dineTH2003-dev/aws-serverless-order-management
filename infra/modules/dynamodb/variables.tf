variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "billing_mode" {
  description = "DynamoDB billing mode: PAY_PER_REQUEST or PROVISIONED"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "enable_pitr" {
  description = "Enable Point-In-Time Recovery for the table"
  type        = bool
  default     = true
}

variable "ttl_attribute" {
  description = "Name of the TTL attribute for auto-expiry"
  type        = string
  default     = "ttl"
}

variable "tags" {
  description = "Additional tags to apply to DynamoDB resources"
  type        = map(string)
  default     = {}
}
