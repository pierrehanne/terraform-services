output "role_arn" {
  description = "ARN of the IAM role (pass to ECS task/execution role inputs, Lambda, etc.)"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.this.name
}

output "role_id" {
  description = "Stable, unique ID of the IAM role"
  value       = aws_iam_role.this.unique_id
}

output "inline_policy_arn" {
  description = "ARN of the customer-managed policy generated from inline_policy_statements (null when none provided)"
  value       = try(aws_iam_policy.inline[0].arn, null)
}

output "custom_policy_arn" {
  description = "ARN of the customer-managed policy created from policy_json (null when not provided)"
  value       = try(aws_iam_policy.custom[0].arn, null)
}
