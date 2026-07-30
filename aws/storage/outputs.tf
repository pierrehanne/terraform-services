output "bucket_id" {
  description = "Name (ID) of the bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "Regional domain name of the bucket"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt objects (null when using AES256 or an externally supplied key)"
  value       = try(module.encryption_kms[0].kms_key_arn, var.kms_key_arn)
}

//---------------------------------------------------------------------
// Analytics (null when the corresponding feature is disabled)
//---------------------------------------------------------------------

output "glue_database_name" {
  description = "Name of the Glue Catalog database"
  value       = try(aws_glue_catalog_database.this[0].name, null)
}

output "glue_crawler_name" {
  description = "Name of the Glue Crawler"
  value       = try(aws_glue_crawler.this[0].name, null)
}

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = try(aws_athena_workgroup.this[0].name, null)
}
