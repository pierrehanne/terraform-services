// Optional AgentCore Memory (short-term event store + optional long-term
// strategies). CMK-encrypted by design when a key is supplied.

resource "aws_bedrockagentcore_memory" "this" {
  count = var.memory != null ? 1 : 0

  name                  = replace(local.name_prefix, "-", "_")
  event_expiry_duration = var.memory.event_expiry_days
  encryption_key_arn    = var.kms_key_arn

  memory_execution_role_arn = var.memory.memory_execution_role_arn

  tags = local.common_tags

  lifecycle {
    precondition {
      condition     = var.kms_key_arn != null
      error_message = "kms_key_arn is required when memory is configured (AgentCore Memory is encrypted with a customer-managed key by design)."
    }
  }
}

resource "aws_bedrockagentcore_memory_strategy" "this" {
  for_each = var.memory != null ? var.memory.strategies : {}

  memory_id = aws_bedrockagentcore_memory.this[0].id
  name      = each.key
  type      = each.value.type

  namespaces = length(each.value.namespaces) > 0 ? each.value.namespaces : null

  memory_execution_role_arn = var.memory.memory_execution_role_arn
}
