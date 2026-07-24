// KMS Key
module "encryption_kms" {
  source                      = "../kms"
  alias                       = local.encryption_kms_alias
  description                 = "KMS Key for secret ${var.secret_name}"
  kms_policy                  = var.kms_policy_json
  kms_rotation_period_in_days = var.kms_rotation_period_in_days
  multi_region                = var.kms_multi_region_key
  tags                        = var.tags
}

// Secret Encrypted
resource "aws_secretsmanager_secret" "encrypted_secret" {
  name                    = "${var.project}-${var.secret_name}"
  description             = "Secret encrypted by KMS for ${var.project} (${var.environment})"
  kms_key_id              = module.encryption_kms.kms_key_id
  policy                  = var.secret_policy_json
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = var.tags
}
