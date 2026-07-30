output "cluster_id" {
  description = "ID of the Aurora cluster"
  value       = aws_rds_cluster.this.id
}

output "cluster_arn" {
  description = "ARN of the Aurora cluster"
  value       = aws_rds_cluster.this.arn
}

output "cluster_resource_id" {
  description = "Region-unique, immutable identifier of the cluster"
  value       = aws_rds_cluster.this.cluster_resource_id
}

output "endpoint" {
  description = "Writer endpoint for the cluster"
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Read-only endpoint, automatically load-balanced across instances"
  value       = aws_rds_cluster.this.reader_endpoint
}

output "port" {
  description = "PostgreSQL port"
  value       = 5432
}

output "database_name" {
  description = "Name of the default database"
  value       = local.database_name
}

output "master_username" {
  description = "Master username (the password is stored in Secrets Manager, see secret_arn)"
  value       = var.master_username
}

output "security_group_id" {
  description = "ID of the security group attached to the cluster instances"
  value       = aws_security_group.this.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for storage encryption and Performance Insights"
  value       = module.encryption_kms.kms_key_arn
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret holding the master credentials"
  value       = module.master_secret.encrypted_secret.arn
}

output "secret_id" {
  description = "ID/name of the Secrets Manager secret holding the master credentials"
  value       = module.master_secret.encrypted_secret.id
}
