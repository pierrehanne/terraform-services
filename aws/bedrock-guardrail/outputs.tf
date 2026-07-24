output "guardrails" {
  description = "Created Amazon Bedrock guardrails and their published versions."

  value = {
    for key, guardrail in aws_bedrock_guardrail.this : key => {
      id   = guardrail.guardrail_id
      arn  = guardrail.guardrail_arn
      name = guardrail.name

      version = {
        id  = aws_bedrock_guardrail_version.this[key].version
        arn = "${guardrail.guardrail_arn}/${aws_bedrock_guardrail_version.this[key].version}"
      }
    }
  }
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt all Bedrock guardrails."
  value       = var.kms_key_arn
}
