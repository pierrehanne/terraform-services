output "repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.this.arn
}

output "repository_url" {
  description = "URL of the repository (use as the image push/pull target, e.g. in docker build/push and ECS task definitions)"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.this.name
}

output "registry_id" {
  description = "Registry ID (AWS account ID) where the repository lives"
  value       = aws_ecr_repository.this.registry_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt images (null when using AES256 or an externally supplied key)"
  value       = try(module.encryption_kms[0].kms_key_arn, var.kms_key_arn)
}
