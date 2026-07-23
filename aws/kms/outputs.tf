output "kms_key_alias_arn" {
  description = "The ARN of the KMS key alias"
  value       = aws_kms_alias.key_alias.arn
}

output "kms_key_arn" {
  description = "The ARN of the KMS key"
  value       = aws_kms_key.key.arn
}

output "kms_key_id" {
  description = "The ID of the KMS key"
  value       = aws_kms_key.key.key_id
}
