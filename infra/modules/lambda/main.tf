data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  prefix   = "${var.project_name}-${var.environment}"
  src_path = "${path.root}/../src"

  functions = {
    create_order = {
      handler     = "orders/create_order.lambda_handler"
      description = "POST /orders — Create a new order"
      dynamodb_actions = [
        "dynamodb:PutItem",
      ]
      kms_actions = [
        "kms:GenerateDataKey",
        "kms:Decrypt",
      ]
    }
    get_order = {
      handler     = "orders/get_order.lambda_handler"
      description = "GET /orders/{orderId} — Get an order"
      dynamodb_actions = [
        "dynamodb:GetItem",
      ]
      kms_actions = [
        "kms:Decrypt",
      ]
    }
    list_orders = {
      handler     = "orders/list_orders.lambda_handler"
      description = "GET /orders — List orders for a user"
      dynamodb_actions = [
        "dynamodb:Query",
      ]
      kms_actions = [
        "kms:Decrypt",
      ]
    }
    delete_order = {
      handler     = "orders/delete_order.lambda_handler"
      description = "DELETE /orders/{orderId} — Soft-delete an order"
      dynamodb_actions = [
        "dynamodb:UpdateItem",
        "dynamodb:GetItem",
      ]
      kms_actions = [
        "kms:GenerateDataKey",
        "kms:Decrypt",
      ]
    }
  }
}

# ── Per-Function Dedicated Least-Privilege IAM Roles ──────────────────────────
resource "aws_iam_role" "function_roles" {
  for_each = local.functions
  name     = "${local.prefix}-${each.key}-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, {
    Name     = "${local.prefix}-${each.key}-role"
    Function = each.key
  })
}

# ── CloudWatch Logs Policy (strictly scoped per function log group) ───────────
resource "aws_iam_role_policy" "function_logs" {
  for_each = local.functions
  name     = "${local.prefix}-${each.key}-logs"
  role     = aws_iam_role.function_roles[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.prefix}-${each.key}*"
    }]
  })
}

# ── DynamoDB & KMS Least-Privilege Policy ─────────────────────────────────────
resource "aws_iam_role_policy" "function_dynamodb" {
  for_each = local.functions
  name     = "${local.prefix}-${each.key}-dynamodb"
  role     = aws_iam_role.function_roles[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = each.value.dynamodb_actions
        Resource = [
          var.dynamodb_table_arn,
          "${var.dynamodb_table_arn}/index/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = each.value.kms_actions
        Resource = var.dynamodb_kms_key_arn
      }
    ]
  })
}

# ── X-Ray Distributed Tracing Policy ──────────────────────────────────────────
resource "aws_iam_role_policy_attachment" "function_xray" {
  for_each   = local.functions
  role       = aws_iam_role.function_roles[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# ── Zip each Lambda function from source ─────────────────────────────────────
data "archive_file" "lambda_zips" {
  for_each    = local.functions
  type        = "zip"
  output_path = "${path.module}/dist/${each.key}.zip"

  source_dir = local.src_path
}

# ── CloudWatch Log Groups (pre-created for retention control) ─────────────────
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = local.functions
  name     = "/aws/lambda/${local.prefix}-${each.key}"

  retention_in_days = 14
}

# ── Lambda Layer for Dependencies (pydantic) ─────────────────────────────────
resource "aws_lambda_layer_version" "dependencies" {
  layer_name          = "${local.prefix}-python-dependencies"
  description         = "Python dependencies (pydantic) for ${var.project_name}"
  filename            = "${path.module}/dist/layer.zip"
  source_code_hash    = fileexists("${path.module}/dist/layer.zip") ? filebase64sha256("${path.module}/dist/layer.zip") : null
  compatible_runtimes = ["python3.11", "python3.12"]
}

# ── Lambda Functions ──────────────────────────────────────────────────────────
resource "aws_lambda_function" "functions" {
  for_each = local.functions

  function_name = "${local.prefix}-${each.key}"
  description   = each.value.description
  role          = aws_iam_role.function_roles[each.key].arn

  filename         = data.archive_file.lambda_zips[each.key].output_path
  source_code_hash = data.archive_file.lambda_zips[each.key].output_base64sha256

  handler     = each.value.handler
  runtime     = "python3.12"
  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_seconds

  environment {
    variables = {
      TABLE_NAME = var.dynamodb_table_name
      LOG_LEVEL  = var.log_level
    }
  }

  layers = [aws_lambda_layer_version.dependencies.arn]

  tracing_config {
    mode = "Active" # X-Ray active tracing
  }

  depends_on = [aws_cloudwatch_log_group.lambda_logs]

  tags = merge(var.tags, {
    Name     = "${local.prefix}-${each.key}"
    Function = each.key
  })
}
