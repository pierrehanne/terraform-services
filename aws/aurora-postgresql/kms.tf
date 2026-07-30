module "encryption_kms" {
  source                      = "../kms"
  alias                       = "alias/rds/${var.project}/${var.environment}/${var.name}"
  description                 = "KMS key for Aurora PostgreSQL cluster ${var.name} (${var.environment})"
  kms_rotation_period_in_days = var.kms_rotation_period_in_days
  tags                        = local.common_tags
}
