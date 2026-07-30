resource "aws_cloudwatch_log_group" "this" {
  for_each = var.services

  name              = "/ecs/${local.name_prefix}/${each.key}"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.log_kms_key_arn

  tags = local.common_tags
}
