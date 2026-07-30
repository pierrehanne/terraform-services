// Optional AgentCore Gateway: fronts tools as MCP with inbound auth (JWT or
// IAM) and CMK encryption. Gateway targets (the individual tools) are left to
// the caller to add against the exported gateway_id, since their configuration
// (Lambda / OpenAPI / MCP schemas) is application-specific.

resource "aws_bedrockagentcore_gateway" "this" {
  count = var.gateway != null ? 1 : 0

  name            = replace(local.name_prefix, "-", "_")
  role_arn        = var.gateway.role_arn
  authorizer_type = var.gateway.authorizer_type
  protocol_type   = "MCP"
  kms_key_arn     = var.kms_key_arn

  dynamic "authorizer_configuration" {
    for_each = var.gateway.authorizer_type == "CUSTOM_JWT" ? [var.gateway.jwt] : []
    content {
      custom_jwt_authorizer {
        discovery_url    = authorizer_configuration.value.discovery_url
        allowed_audience = length(authorizer_configuration.value.allowed_audience) > 0 ? authorizer_configuration.value.allowed_audience : null
        allowed_clients  = length(authorizer_configuration.value.allowed_clients) > 0 ? authorizer_configuration.value.allowed_clients : null
        allowed_scopes   = length(authorizer_configuration.value.allowed_scopes) > 0 ? authorizer_configuration.value.allowed_scopes : null
      }
    }
  }

  dynamic "protocol_configuration" {
    for_each = var.gateway.mcp_instructions != null ? [var.gateway.mcp_instructions] : []
    content {
      mcp {
        instructions = protocol_configuration.value
      }
    }
  }

  tags = local.common_tags

  lifecycle {
    precondition {
      condition     = var.kms_key_arn != null
      error_message = "kms_key_arn is required when gateway is configured (the Gateway is encrypted with a customer-managed key by design)."
    }
  }
}
