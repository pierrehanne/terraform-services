variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "kms_key_arn" {
  description = "Existing KMS key used to encrypt all Bedrock guardrails."
  type        = string
}

variable "guardrails" {
  description = "Bedrock guardrails to create."

  type = map(object({
    description            = optional(string)
    version_description    = optional(string, "Production version")
    blocked_input_message  = optional(string)
    blocked_output_message = optional(string)

    content_filters = optional(list(object({
      type            = string
      input_strength  = string
      output_strength = string
    })), [])

    denied_topics = optional(list(object({
      name       = string
      definition = string
      examples   = list(string)
    })), [])

    denied_words = optional(list(string), [])

    managed_word_lists = optional(list(string), ["PROFANITY"])

    pii_entities = optional(list(object({
      type   = string
      action = string
    })), [])

    contextual_grounding_filters = optional(list(object({
      type      = string
      threshold = number
    })), [])
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}
