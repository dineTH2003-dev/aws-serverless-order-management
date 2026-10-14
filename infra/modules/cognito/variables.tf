variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "password_minimum_length" {
  description = "Minimum password length for Cognito User Pool"
  type        = number
  default     = 8
}

variable "mfa_configuration" {
  description = "MFA configuration: OFF, ON, or OPTIONAL"
  type        = string
  default     = "OPTIONAL"
  validation {
    condition     = contains(["OFF", "ON", "OPTIONAL"], var.mfa_configuration)
    error_message = "mfa_configuration must be OFF, ON, or OPTIONAL."
  }
}

variable "access_token_validity_hours" {
  description = "Access token validity in hours (1-24)"
  type        = number
  default     = 1
}

variable "refresh_token_validity_days" {
  description = "Refresh token validity in days (1-3650)"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Additional tags to apply to Cognito resources"
  type        = map(string)
  default     = {}
}
