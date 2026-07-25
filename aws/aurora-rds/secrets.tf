resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

module "master_secret" {
  source                  = "../secrets-manager"
  project                 = var.project
  environment             = var.environment
  secret_name             = "${var.name}-master-credentials"
  recovery_window_in_days = var.secret_recovery_window_in_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "master" {
  secret_id = module.master_secret.encrypted_secret.id

  secret_string = jsonencode({
    engine   = "postgres"
    username = var.master_username
    password = random_password.master.result
    host     = aws_rds_cluster.this.endpoint
    reader   = aws_rds_cluster.this.reader_endpoint
    port     = 5432
    dbname   = local.database_name
  })
}
