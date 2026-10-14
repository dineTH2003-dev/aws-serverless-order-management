data "aws_region" "current" {}

locals {
  pool_name = "${var.project_name}-users-${var.environment}"
}

# ── Cognito User Pool ─────────────────────────────────────────────────────────
resource "aws_cognito_user_pool" "main" {
  name = local.pool_name

  # ── Username / alias configuration ──────────────────────────────────────────
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # ── Password policy ──────────────────────────────────────────────────────────
  password_policy {
    minimum_length                   = var.password_minimum_length
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # ── MFA configuration ────────────────────────────────────────────────────────
  mfa_configuration = var.mfa_configuration

  software_token_mfa_configuration {
    enabled = true
  }

  # ── Account recovery ─────────────────────────────────────────────────────────
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # ── Email verification ───────────────────────────────────────────────────────
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Your ${var.project_name} verification code"
    email_message        = "Your verification code is {####}"
  }

  # ── User schema ───────────────────────────────────────────────────────────────
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 5
      max_length = 254
    }
  }

  # ── Advanced security (anomaly detection) ────────────────────────────────────
  user_pool_add_ons {
    advanced_security_mode = "AUDIT"
  }

  tags = merge(var.tags, {
    Name = local.pool_name
  })
}

# ── Cognito User Pool App Client ──────────────────────────────────────────────
resource "aws_cognito_user_pool_client" "app" {
  name         = "${var.project_name}-app-client-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id

  # No client secret — mobile/SPA compatible
  generate_secret = false

  # ── Auth flows ───────────────────────────────────────────────────────────────
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]

  # ── Token validity ───────────────────────────────────────────────────────────
  access_token_validity  = var.access_token_validity_hours
  refresh_token_validity = var.refresh_token_validity_days
  id_token_validity      = var.access_token_validity_hours

  token_validity_units {
    access_token  = "hours"
    refresh_token = "days"
    id_token      = "hours"
  }

  # ── Prevent token reuse attacks ──────────────────────────────────────────────
  enable_token_revocation       = true
  prevent_user_existence_errors = "ENABLED"

  # ── Read/write attributes ────────────────────────────────────────────────────
  read_attributes  = ["email", "email_verified"]
  write_attributes = ["email"]
}

# ── Cognito User Pool Domain (for hosted UI / token endpoint) ─────────────────
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-${var.environment}-auth"
  user_pool_id = aws_cognito_user_pool.main.id
}
