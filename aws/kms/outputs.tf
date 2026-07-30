output "kms_key_alias_arn" {
  description = "The ARN of the KMS key alias"
  value       = aws_kms_alias.this.arn
}

output "kms_key_arn" {
  description = "The ARN of the KMS key"
  value       = aws_kms_key.this.arn
}

output "kms_key_id" {
  description = "The ID of the KMS key"
  value       = aws_kms_key.this.key_id
}
