locals {
  encryption_kms_alias = "alias/secretsmanager/${var.project}/${var.environment}/${var.secret_name}"

  common_tags = merge({ Project = var.project, Environment = var.environment }, var.tags)
}

module "encryption_kms" {
  source                      = "../kms"
  alias                       = local.encryption_kms_alias
  description                 = "KMS Key for secret ${var.secret_name}"
  kms_policy                  = var.kms_policy_json
  kms_rotation_period_in_days = var.kms_rotation_period_in_days
  multi_region                = var.kms_multi_region_key
  tags                        = local.common_tags
}

resource "aws_secretsmanager_secret" "this" {
  name                    = "${var.project}-${var.secret_name}"
  description             = "Secret encrypted by KMS for ${var.project} (${var.environment})"
  kms_key_id              = module.encryption_kms.kms_key_id
  policy                  = var.secret_policy_json
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = merge({ Name = "${var.project}-${var.secret_name}" }, local.common_tags)
}
