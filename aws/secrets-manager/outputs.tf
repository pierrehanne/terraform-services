output "encrypted_secret" {
  description = "Encrypted secret and its associated KMS key."

  value = {
    id   = aws_secretsmanager_secret.encrypted_secret.id
    name = aws_secretsmanager_secret.encrypted_secret.name
    arn  = aws_secretsmanager_secret.encrypted_secret.arn

    kms = {
      id        = module.encryption_kms.kms_key_id
      arn       = module.encryption_kms.kms_key_arn
      alias     = local.encryption_kms_alias
      alias_arn = module.encryption_kms.kms_key_alias_arn
    }
  }
}
