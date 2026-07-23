output "guardrail_id" {
  description = "The ID of the Bedrock guardrail"
  value       = aws_bedrock_guardrail.guardrail.guardrail_id
}

output "guardrail_arn" {
  description = "The ARN of the Bedrock guardrail"
  value       = aws_bedrock_guardrail.guardrail.guardrail_arn
}

output "guardrail_name" {
  description = "The name of the Bedrock guardrail"
  value       = aws_bedrock_guardrail.guardrail.name
}

output "guardrail_version_id" {
  description = "The ID of the guardrail version"
  value       = aws_bedrock_guardrail_version.guardrail_version.version
}

output "guardrail_version_arn" {
  description = "The ARN of the guardrail version"
  value       = "${aws_bedrock_guardrail.guardrail.guardrail_arn}/${aws_bedrock_guardrail_version.guardrail_version.version}"
}

output "guardrail_kms_key_id" {
  description = "The ID of the KMS key used for guardrail encryption"
  value       = var.create_kms_key && var.kms_key_arn == null ? module.guardrail_kms[0].kms_key_id : null
}

output "guardrail_kms_key_arn" {
  description = "The ARN of the KMS key used for guardrail encryption"
  value       = var.kms_key_arn != null ? var.kms_key_arn : (var.create_kms_key ? module.guardrail_kms[0].kms_key_arn : null)
}

output "guardrail_kms_key_alias" {
  description = "The alias of the KMS key used for guardrail encryption"
  value       = var.create_kms_key && var.kms_key_arn == null ? local.encryption_kms_alias : null
}
