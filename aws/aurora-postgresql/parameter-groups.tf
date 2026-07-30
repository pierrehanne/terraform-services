locals {
  engine_major_version   = split(".", var.engine_version)[0]
  parameter_group_family = "aurora-postgresql${local.engine_major_version}"
}

resource "aws_rds_cluster_parameter_group" "this" {
  name        = local.name_prefix
  description = "Cluster parameter group for ${var.name}"
  family      = local.parameter_group_family

  dynamic "parameter" {
    for_each = var.cluster_parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = merge(
    { Name = local.name_prefix },
    local.common_tags
  )
}

resource "aws_db_parameter_group" "this" {
  name        = local.name_prefix
  description = "Instance parameter group for ${var.name}"
  family      = local.parameter_group_family

  dynamic "parameter" {
    for_each = var.instance_parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = merge(
    { Name = local.name_prefix },
    local.common_tags
  )
}
