# KMS Key for Guardrail Encryption
module "guardrail_kms" {
  count = var.guardrail_create_kms_key && var.guardrail_kms_key_arn == null ? 1 : 0

  source = "../kms"

  alias                       = local.encryption_kms_alias
  description                 = "KMS key for encrypting Bedrock guardrail ${var.project}-${var.environment}-${var.guardrail_name}"
  enable_key_rotation         = true
  multi_region                = var.guardrail_kms_multi_region_key
  kms_policy                  = var.guardrail_kms_policy_json
  kms_rotation_period_in_days = var.guardrail_kms_rotation_period_in_days
  tags                        = var.tags
}

# Bedrock Guardrail with Enhanced Security
resource "aws_bedrock_guardrail" "guardrail" {
  name                      = "${var.project}-${var.environment}-${var.guardrail_name}"
  description               = "Bedrock guardrail for ${var.project} ${var.environment} environment - Provides content filtering, PII protection, and topic restrictions"
  blocked_input_messaging   = var.guardrail_blocked_input_messaging
  blocked_outputs_messaging = var.guardrail_blocked_outputs_messaging
  kms_key_arn               = var.guardrail_kms_key_arn != null ? var.guardrail_kms_key_arn : (var.guardrail_create_kms_key ? module.guardrail_kms[0].kms_key_arn : null)

  tags = var.tags

  # Content Policy - Harmful Content Detection
  dynamic "content_policy_config" {
    for_each = length(var.content_filters) > 0 ? [1] : []

    content {
      dynamic "filters_config" {
        for_each = var.content_filters

        content {
          type            = filters_config.value.type
          input_strength  = filters_config.value.input_strength
          output_strength = filters_config.value.output_strength
        }
      }
    }
  }

  # Topic Policy - Deny Specific Topics
  dynamic "topic_policy_config" {
    for_each = length(var.denied_topics) > 0 ? [1] : []

    content {
      dynamic "topics_config" {
        for_each = var.denied_topics

        content {
          name       = topics_config.value.name
          definition = topics_config.value.definition
          examples   = topics_config.value.examples
          type       = "DENY"
        }
      }
    }
  }

  # Word Policy - Block Specific Words and Profanity
  dynamic "word_policy_config" {
    for_each = length(var.guardrail_denied_words) > 0 || length(var.guardrail_managed_word_lists) > 0 ? [1] : []

    content {
      # Custom denied words
      dynamic "words_config" {
        for_each = var.guardrail_denied_words

        content {
          text = words_config.value
        }
      }

      # Managed word lists (e.g., PROFANITY)
      dynamic "managed_word_lists_config" {
        for_each = var.guardrail_managed_word_lists

        content {
          type = managed_word_lists_config.value
        }
      }
    }
  }

  # Sensitive Information Policy - PII Detection and Protection
  dynamic "sensitive_information_policy_config" {
    for_each = var.guardrail_enable_pii_detection ? [1] : []

    content {
      dynamic "pii_entities_config" {
        for_each = var.guardrail_pii_entities

        content {
          type   = pii_entities_config.value.type
          action = pii_entities_config.value.action
        }
      }
    }
  }

  # Contextual Grounding Policy - Prevent Hallucinations (optional)
  dynamic "contextual_grounding_policy_config" {
    for_each = length(var.guardrail_contextual_grounding_filters) > 0 ? [1] : []

    content {
      dynamic "filters_config" {
        for_each = var.guardrail_contextual_grounding_filters

        content {
          type      = filters_config.value.type
          threshold = filters_config.value.threshold
        }
      }
    }
  }
}

# Guardrail Version
resource "aws_bedrock_guardrail_version" "guardrail_version" {
  guardrail_arn = aws_bedrock_guardrail.guardrail.guardrail_arn
  description   = var.guardrail_version_description
}
