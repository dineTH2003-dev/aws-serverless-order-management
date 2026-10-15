locals {
  waf_name = "${var.project_name}-web-acl-${var.environment}"
}

# ── WAFv2 WebACL (Regional for API Gateway) ───────────────────────────────────
resource "aws_wafv2_web_acl" "main" {
  name        = local.waf_name
  description = "WAF protection for ${var.project_name} API Gateway ${var.environment}"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # ── Rule 1: AWS Managed Common Rule Set (OWASP Top 10) ──────────────────────
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # ── Rule 2: AWS Managed Known Bad Inputs Rule Set ───────────────────────────
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputsMetric"
      sampled_requests_enabled   = true
    }
  }

  # ── Rule 3: AWS Managed SQL Injection Rule Set ──────────────────────────────
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 30

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  # ── Rule 4: Rate-based Rule (IP Throttling) ──────────────────────────────────
  rule {
    name     = "RateLimitPerIP"
    priority = 40

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_per_5min
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-web-acl-main"
    sampled_requests_enabled   = true
  }

  tags = merge(var.tags, {
    Name = local.waf_name
  })
}

# ── Associate WebACL with API Gateway Stage ───────────────────────────────────
resource "aws_wafv2_web_acl_association" "api_gateway" {
  resource_arn = var.api_gateway_stage_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# ── CloudWatch Log Group & Logging Configuration for WAF ─────────────────────
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "aws-waf-logs-${var.project_name}-${var.environment}"
  retention_in_days = 14

  tags = merge(var.tags, {
    Name = "aws-waf-logs-${var.project_name}-${var.environment}"
  })
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn
}
