output "user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_endpoint" {
  description = "Cognito User Pool endpoint (JWKS URL base)"
  value       = aws_cognito_user_pool.main.endpoint
}

output "app_client_id" {
  description = "Cognito App Client ID"
  value       = aws_cognito_user_pool_client.app.id
}

output "domain" {
  description = "Cognito User Pool hosted UI domain prefix"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "jwks_uri" {
  description = "JWKS URI for JWT token validation"
  value       = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.main.id}/.well-known/jwks.json"
}
