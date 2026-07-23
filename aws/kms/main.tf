resource "aws_kms_key" "key" {
  description         = var.description
  enable_key_rotation = var.enable_key_rotation
  multi_region        = var.multi_region
  policy              = var.kms_policy
  tags                = merge(var.tags, { "Name" = var.alias })
}

resource "aws_kms_alias" "key_alias" {
  name          = var.alias
  target_key_id = aws_kms_key.key.key_id
}
