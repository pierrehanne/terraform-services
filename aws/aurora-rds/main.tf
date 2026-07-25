locals {
  database_name = coalesce(var.database_name, replace(var.name, "-", "_"))
}

resource "aws_db_subnet_group" "this" {
  name        = "${var.project}-${var.name}"
  description = "Subnet group for Aurora PostgreSQL cluster ${var.name}"
  subnet_ids  = var.subnet_ids

  tags = merge(
    { Name = "${var.project}-${var.name}" },
    var.tags
  )
}

resource "aws_rds_cluster" "this" {
  cluster_identifier              = "${var.project}-${var.name}"
  database_name                   = local.database_name
  engine                          = "aurora-postgresql"
  engine_mode                     = "provisioned"
  engine_version                  = var.engine_version
  master_username                 = var.master_username
  master_password                 = random_password.master.result
  db_subnet_group_name            = aws_db_subnet_group.this.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name
  vpc_security_group_ids          = [aws_security_group.aurora.id]

  storage_encrypted = true
  kms_key_id        = module.encryption_kms.kms_key_arn

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window

  deletion_protection         = var.deletion_protection
  skip_final_snapshot         = var.skip_final_snapshot
  final_snapshot_identifier   = var.skip_final_snapshot ? null : "${var.project}-${var.name}-final"
  apply_immediately           = var.apply_immediately
  allow_major_version_upgrade = var.allow_major_version_upgrade

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  serverlessv2_scaling_configuration {
    min_capacity             = var.min_capacity
    max_capacity             = var.max_capacity
    seconds_until_auto_pause = var.min_capacity == 0 ? var.seconds_until_auto_pause : null
  }

  lifecycle {
    ignore_changes = [master_password]
  }

  tags = merge(
    { Name = "${var.project}-${var.name}" },
    var.tags
  )
}

resource "aws_rds_cluster_instance" "this" {
  count = var.instance_count

  identifier         = "${var.project}-${var.name}-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  db_subnet_group_name    = aws_db_subnet_group.this.name
  db_parameter_group_name = aws_db_parameter_group.this.name

  publicly_accessible        = var.publicly_accessible
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_enabled ? module.encryption_kms.kms_key_arn : null

  tags = merge(
    { Name = "${var.project}-${var.name}-${count.index + 1}" },
    var.tags
  )
}
