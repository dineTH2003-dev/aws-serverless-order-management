data "aws_region" "current" {}

locals {
  prefix = "${var.project_name}-${var.environment}"
}

# ── SNS Topic for CloudWatch Alarms ──────────────────────────────────────────
resource "aws_sns_topic" "alerts" {
  name = "${local.prefix}-alerts"

  tags = merge(var.tags, {
    Name = "${local.prefix}-alerts"
  })
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ── CloudWatch Alarm: API Gateway 5XX Errors ─────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${local.prefix}-apigw-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "API Gateway 5XX error count exceeded threshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = var.api_gateway_name
    Stage   = var.environment
  }
}

# ── CloudWatch Alarm: API Gateway High Latency (P95 > 2s) ───────────────────
resource "aws_cloudwatch_metric_alarm" "api_latency" {
  alarm_name          = "${local.prefix}-apigw-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = 60
  extended_statistic  = "p95"
  threshold           = 2000 # 2 seconds
  alarm_description   = "API Gateway P95 latency exceeded 2 seconds"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = var.api_gateway_name
    Stage   = var.environment
  }
}

# ── CloudWatch Alarm: Lambda Errors ──────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = var.lambda_function_names

  alarm_name          = "${local.prefix}-${each.key}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Errors detected in Lambda function ${each.value}"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }
}

# ── CloudWatch Alarm: Lambda High Duration ───────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  for_each = var.lambda_function_names

  alarm_name          = "${local.prefix}-${each.key}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  extended_statistic  = "p99"
  threshold           = 5000 # 5 seconds
  alarm_description   = "P99 duration for ${each.value} exceeded 5 seconds"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }
}

# ── CloudWatch Unified Observability Dashboard ───────────────────────────────
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", var.api_gateway_name, "Stage", var.environment, { stat = "Sum", label = "Total Requests" }],
            [".", "4XXError", ".", ".", ".", ".", { stat = "Sum", label = "4XX Errors", color = "#ff7f0e" }],
            [".", "5XXError", ".", ".", ".", ".", { stat = "Sum", label = "5XX Errors", color = "#d62728" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "API Gateway Requests & Errors"
          period  = 60
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", var.api_gateway_name, "Stage", var.environment, { stat = "Average", label = "Avg Latency (ms)" }],
            [".", "Latency", ".", ".", ".", ".", { stat = "p95", label = "P95 Latency (ms)" }],
            [".", "IntegrationLatency", ".", ".", ".", ".", { stat = "Average", label = "Backend Integration Latency (ms)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "API Gateway Latency Breakdown"
          period  = 60
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            for k, fn in var.lambda_function_names :
            ["AWS/Lambda", "Invocations", "FunctionName", fn, { stat = "Sum", label = "${k} Invocations" }]
          ]
          view    = "timeSeries"
          stacked = true
          region  = data.aws_region.current.name
          title   = "Lambda Invocations by Function"
          period  = 60
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            for k, fn in var.lambda_function_names :
            ["AWS/Lambda", "Errors", "FunctionName", fn, { stat = "Sum", label = "${k} Errors" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Lambda Errors by Function"
          period  = 60
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", var.dynamodb_table_name, { stat = "Sum", label = "Read Capacity Units" }],
            [".", "ConsumedWriteCapacityUnits", ".", ".", { stat = "Sum", label = "Write Capacity Units" }],
            [".", "ThrottledRequests", ".", ".", { stat = "Sum", label = "Throttled Requests", color = "#d62728" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "DynamoDB Capacity & Throttles"
          period  = 60
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/WAFV2", "AllowedRequests", "WebACL", var.waf_web_acl_name, "Region", data.aws_region.current.name, "Rule", "ALL", { stat = "Sum", label = "WAF Allowed" }],
            [".", "BlockedRequests", ".", ".", ".", ".", ".", ".", { stat = "Sum", label = "WAF Blocked", color = "#d62728" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "AWS WAF Traffic & Blocked Attacks"
          period  = 60
        }
      }
    ]
  })
}
