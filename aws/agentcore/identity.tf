// Optional Identity plane: a workload identity for the agent, and downstream
// (outbound) credential providers stored in the token vault. Security by
// design: the token vault is encrypted with the supplied CMK, and every secret
// is passed as a write-only value so it never lands in Terraform state.

locals {
  identity_enabled = var.identity != null
  # The vault CMK is needed whenever any credential is stored.
  store_credentials = local.identity_enabled && (
    length(var.identity.oauth2_providers) > 0 || length(var.identity.api_key_providers) > 0
  )
}

resource "aws_bedrockagentcore_token_vault_cmk" "this" {
  count = local.store_credentials ? 1 : 0

  kms_configuration {
    key_type    = "CustomerManagedKey"
    kms_key_arn = var.kms_key_arn
  }

  lifecycle {
    precondition {
      condition     = var.kms_key_arn != null
      error_message = "kms_key_arn is required when identity.credential providers are configured (the token vault is encrypted with a customer-managed key by design)."
    }
  }
}

resource "aws_bedrockagentcore_workload_identity" "this" {
  count = local.identity_enabled && var.identity.create_workload_identity ? 1 : 0

  name                                = replace(local.name_prefix, "-", "_")
  allowed_resource_oauth2_return_urls = length(var.identity.workload_return_urls) > 0 ? var.identity.workload_return_urls : null
}

//---------------------------------------------------------------------
// OAuth2 credential providers (write-only secrets)
//---------------------------------------------------------------------

resource "aws_bedrockagentcore_oauth2_credential_provider" "this" {
  for_each = local.identity_enabled ? var.identity.oauth2_providers : {}

  name                       = each.key
  credential_provider_vendor = each.value.vendor

  oauth2_provider_config {
    custom_oauth2_provider_config {
      client_id_wo                  = each.value.client_id_wo
      client_secret_wo              = each.value.client_secret_wo
      client_credentials_wo_version = each.value.client_credentials_wo_version

      dynamic "oauth_discovery" {
        for_each = each.value.discovery_url != null ? [each.value.discovery_url] : []
        content {
          discovery_url = oauth_discovery.value
        }
      }
    }
  }

  # The vault CMK must exist before secrets are written to it.
  depends_on = [aws_bedrockagentcore_token_vault_cmk.this]

  tags = local.common_tags
}

//---------------------------------------------------------------------
// API-key credential providers (write-only secrets)
//---------------------------------------------------------------------

resource "aws_bedrockagentcore_api_key_credential_provider" "this" {
  for_each = local.identity_enabled ? var.identity.api_key_providers : {}

  name               = each.key
  api_key_wo         = each.value.api_key_wo
  api_key_wo_version = each.value.api_key_wo_version

  depends_on = [aws_bedrockagentcore_token_vault_cmk.this]

  tags = local.common_tags
}
