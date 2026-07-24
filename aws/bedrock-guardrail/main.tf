resource "aws_bedrock_guardrail" "this" {
  for_each = var.guardrails

  name        = "${var.project}-${var.environment}-${each.key}"
  kms_key_arn = var.kms_key_arn
  tags        = var.tags

  description = coalesce(
    each.value.description,
    "Bedrock guardrail for ${each.key}"
  )

  blocked_input_messaging = coalesce(
    each.value.blocked_input_message,
    "This request violates the organization's AI usage policy."
  )

  blocked_outputs_messaging = coalesce(
    each.value.blocked_output_message,
    "The generated response violates the organization's AI usage policy."
  )

  dynamic "content_policy_config" {
    for_each = length(each.value.content_filters) > 0 ? [1] : []

    content {
      dynamic "filters_config" {
        for_each = each.value.content_filters
        content {
          type            = filters_config.value.type
          input_strength  = filters_config.value.input_strength
          output_strength = filters_config.value.output_strength
        }
      }

    }
  }

  dynamic "topic_policy_config" {
    for_each = length(each.value.denied_topics) > 0 ? [1] : []

    content {

      dynamic "topics_config" {
        for_each = each.value.denied_topics

        content {
          name       = topics_config.value.name
          definition = topics_config.value.definition
          examples   = topics_config.value.examples
          type       = "DENY"
        }
      }
    }
  }

  dynamic "word_policy_config" {
    for_each = (
      length(each.value.denied_words) > 0 ||
      length(each.value.managed_word_lists) > 0
    ) ? [1] : []

    content {
      dynamic "words_config" {
        for_each = each.value.denied_words

        content {
          text = words_config.value
        }
      }

      dynamic "managed_word_lists_config" {
        for_each = each.value.managed_word_lists

        content {
          type = managed_word_lists_config.value
        }
      }

    }
  }

  dynamic "sensitive_information_policy_config" {
    for_each = length(each.value.pii_entities) > 0 ? [1] : []

    content {
      dynamic "pii_entities_config" {
        for_each = each.value.pii_entities

        content {
          type   = pii_entities_config.value.type
          action = pii_entities_config.value.action
        }
      }

    }
  }

  dynamic "contextual_grounding_policy_config" {
    for_each = length(each.value.contextual_grounding_filters) > 0 ? [1] : []

    content {
      dynamic "filters_config" {
        for_each = each.value.contextual_grounding_filters

        content {
          type      = filters_config.value.type
          threshold = filters_config.value.threshold
        }
      }

    }
  }
}

resource "aws_bedrock_guardrail_version" "this" {
  for_each = aws_bedrock_guardrail.this

  guardrail_arn = each.value.guardrail_arn

  description = coalesce(
    var.guardrails[each.key].version_description,
    "Production version"
  )
}
