data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  api_name = "${var.project_name}-api-${var.environment}"
}

# ── REST API ──────────────────────────────────────────────────────────────────
resource "aws_api_gateway_rest_api" "main" {
  name        = local.api_name
  description = "REST API for ${var.project_name} (${var.environment})"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(var.tags, {
    Name = local.api_name
  })
}

# ── Cognito Authorizer ────────────────────────────────────────────────────────
resource "aws_api_gateway_authorizer" "cognito" {
  name          = "${var.project_name}-cognito-authorizer-${var.environment}"
  rest_api_id   = aws_api_gateway_rest_api.main.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [var.cognito_user_pool_arn]
  identity_source = "method.request.header.Authorization"
}

# ── Request Validator ─────────────────────────────────────────────────────────
resource "aws_api_gateway_request_validator" "validator" {
  name                        = "${var.project_name}-validator-${var.environment}"
  rest_api_id                 = aws_api_gateway_rest_api.main.id
  validate_request_body       = true
  validate_request_parameters = true
}

# ── API Resources ─────────────────────────────────────────────────────────────
# /orders
resource "aws_api_gateway_resource" "orders" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "orders"
}

# /orders/{orderId}
resource "aws_api_gateway_resource" "order_id" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.orders.id
  path_part   = "{orderId}"
}

# ── Methods: /orders POST (create_order) ───────────────────────────────────────
resource "aws_api_gateway_method" "post_order" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_validator_id = aws_api_gateway_request_validator.validator.id
}

resource "aws_api_gateway_integration" "post_order" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.orders.id
  http_method             = aws_api_gateway_method.post_order.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arns["create_order"]
}

# ── Methods: /orders GET (list_orders) ────────────────────────────────────────
resource "aws_api_gateway_method" "get_orders" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_parameters = {
    "method.request.querystring.status"   = false
    "method.request.querystring.limit"    = false
    "method.request.querystring.lastKey"  = false
  }
}

resource "aws_api_gateway_integration" "get_orders" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.orders.id
  http_method             = aws_api_gateway_method.get_orders.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arns["list_orders"]
}

# ── Methods: /orders/{orderId} GET (get_order) ────────────────────────────────
resource "aws_api_gateway_method" "get_order" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.order_id.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_parameters = {
    "method.request.path.orderId" = true
  }
}

resource "aws_api_gateway_integration" "get_order" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.order_id.id
  http_method             = aws_api_gateway_method.get_order.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arns["get_order"]
}

# ── Methods: /orders/{orderId} DELETE (delete_order) ──────────────────────────
resource "aws_api_gateway_method" "delete_order" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.order_id.id
  http_method   = "DELETE"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_parameters = {
    "method.request.path.orderId" = true
  }
}

resource "aws_api_gateway_integration" "delete_order" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.order_id.id
  http_method             = aws_api_gateway_method.delete_order.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arns["delete_order"]
}

# ── CORS OPTIONS: /orders ─────────────────────────────────────────────────────
resource "aws_api_gateway_method" "options_orders" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_orders" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.options_orders.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{"statusCode": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_orders_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.options_orders.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_orders_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.options_orders.http_method
  status_code = aws_api_gateway_method_response.options_orders_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.options_orders]
}

# ── CORS OPTIONS: /orders/{orderId} ───────────────────────────────────────────
resource "aws_api_gateway_method" "options_order_id" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.order_id.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_order_id" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.order_id.id
  http_method = aws_api_gateway_method.options_order_id.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{"statusCode": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_order_id_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.order_id.id
  http_method = aws_api_gateway_method.options_order_id.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_order_id_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.order_id.id
  http_method = aws_api_gateway_method.options_order_id.http_method
  status_code = aws_api_gateway_method_response.options_order_id_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.options_order_id]
}

# ── Lambda Permissions for API Gateway ────────────────────────────────────────
resource "aws_lambda_permission" "apigw_lambda" {
  for_each = var.lambda_function_names

  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# ── CloudWatch Access Log Group ───────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/api-gateway/${local.api_name}"
  retention_in_days = 14

  tags = merge(var.tags, {
    Name = "/aws/api-gateway/${local.api_name}"
  })
}

# ── Deployment & Stage ────────────────────────────────────────────────────────
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.orders.id,
      aws_api_gateway_resource.order_id.id,
      aws_api_gateway_method.post_order.id,
      aws_api_gateway_integration.post_order.id,
      aws_api_gateway_method.get_orders.id,
      aws_api_gateway_integration.get_orders.id,
      aws_api_gateway_method.get_order.id,
      aws_api_gateway_integration.get_order.id,
      aws_api_gateway_method.delete_order.id,
      aws_api_gateway_integration.delete_order.id,
      aws_api_gateway_method.options_orders.id,
      aws_api_gateway_integration.options_orders.id,
      aws_api_gateway_method.options_order_id.id,
      aws_api_gateway_integration.options_order_id.id,
      aws_api_gateway_authorizer.cognito.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.post_order,
    aws_api_gateway_integration.get_orders,
    aws_api_gateway_integration.get_order,
    aws_api_gateway_integration.delete_order,
    aws_api_gateway_integration.options_orders,
    aws_api_gateway_integration.options_order_id,
  ]
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = merge(var.tags, {
    Name = "${local.api_name}-${var.environment}"
  })
}

# ── Method Settings (Metrics + Throttling) ───────────────────────────────────
resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    logging_level          = "INFO"
    data_trace_enabled     = false
    throttling_burst_limit = var.throttling_burst_limit
    throttling_rate_limit  = var.throttling_rate_limit
  }
}
