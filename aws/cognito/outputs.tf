output "user_pool_id" {
  description = "ID of the Cognito user pool"
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  description = "ARN of the Cognito user pool (feed into the ALB authenticate-cognito action's user_pool_arn)"
  value       = aws_cognito_user_pool.this.arn
}

output "user_pool_client_id" {
  description = "ID of the app client (feed into the ALB authenticate-cognito action's user_pool_client_id)"
  value       = aws_cognito_user_pool_client.this.id
}

output "user_pool_domain" {
  description = "Hosted-UI domain prefix (feed into the ALB authenticate-cognito action's user_pool_domain)"
  value       = aws_cognito_user_pool_domain.this.domain
}

output "user_pool_endpoint" {
  description = "Endpoint of the user pool (e.g. cognito-idp.<region>.amazonaws.com/<pool-id>)"
  value       = aws_cognito_user_pool.this.endpoint
}
