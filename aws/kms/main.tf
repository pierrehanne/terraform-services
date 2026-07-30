resource "aws_kms_key" "this" {
  description             = var.description
  enable_key_rotation     = var.enable_key_rotation
  rotation_period_in_days = var.enable_key_rotation ? var.kms_rotation_period_in_days : null
  multi_region            = var.multi_region
  policy                  = var.kms_policy
  tags                    = merge(var.tags, { "Name" = var.alias })
}

resource "aws_kms_alias" "this" {
  name          = var.alias
  target_key_id = aws_kms_key.this.key_id
}
