output "encrypted_secret_id" {
  description = "The ID of the encrypted secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.encrypted_secret.id
}

output "encrypted_secret_name" {
  description = "The name of the encrypted secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.encrypted_secret.name
}

output "encrypted_secret_arn" {
  description = "The ARN of the encrypted secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.encrypted_secret.arn
}

output "encrypted_secret_key_id" {
  description = "The ID of the KMS key used to encrypt the secret"
  value       = module.encryption_kms.kms_key_id
}

output "encrypted_secret_key_arn" {
  description = "The ARN of the KMS key used to encrypt the secret"
  value       = module.encryption_kms.kms_key_arn
}

output "encrypted_secret_key_alias" {
  description = "The alias of the KMS key used to encrypt the secret"
  value       = local.encryption_kms_alias
}

output "encrypted_secret_key_alias_arn" {
  description = "The ARN of the KMS key alias used to encrypt the secret"
  value       = module.encryption_kms.kms_key_alias_arn
}
