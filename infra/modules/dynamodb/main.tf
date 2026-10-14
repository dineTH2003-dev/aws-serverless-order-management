locals {
  table_name = "${var.project_name}-orders-${var.environment}"
}

# ── KMS Key for DynamoDB encryption at rest ───────────────────────────────────
resource "aws_kms_key" "dynamodb" {
  description             = "KMS key for ${local.table_name} DynamoDB table encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${local.table_name}-kms"
  })
}

resource "aws_kms_alias" "dynamodb" {
  name          = "alias/${local.table_name}"
  target_key_id = aws_kms_key.dynamodb.key_id
}

# ── Main Orders DynamoDB Table ────────────────────────────────────────────────
resource "aws_dynamodb_table" "orders" {
  name         = local.table_name
  billing_mode = var.billing_mode
  hash_key     = "PK"
  range_key    = "SK"

  # ── Attribute definitions (only keys and index attributes go here) ──────────
  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  # ── GSI-1: Query all orders by userId, sorted by createdAt ─────────────────
  global_secondary_index {
    name            = "userId-createdAt-index"
    hash_key        = "userId"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  # ── GSI-2: Query orders by status, sorted by createdAt ─────────────────────
  global_secondary_index {
    name            = "status-createdAt-index"
    hash_key        = "status"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  # ── TTL for automatic item expiry ───────────────────────────────────────────
  ttl {
    attribute_name = var.ttl_attribute
    enabled        = true
  }

  # ── Point-in-time recovery ──────────────────────────────────────────────────
  point_in_time_recovery {
    enabled = var.enable_pitr
  }

  # ── Encryption at rest with customer-managed KMS key ───────────────────────
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  tags = merge(var.tags, {
    Name = local.table_name
  })
}

# ── CloudWatch Alarm: Throttled requests ─────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  alarm_name          = "${local.table_name}-throttled-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "DynamoDB throttled requests detected on ${local.table_name}"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.orders.name
  }
}
