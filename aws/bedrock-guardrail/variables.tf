locals {
  encryption_kms_alias = "alias/bedrock/guardrail/${var.project}/${var.environment}/${var.guardrail_name}"
}

variable "project" {
  description = "Project name used for naming and organizing guardrails"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
}

variable "guardrail_name" {
  description = "Name of the Bedrock guardrail"
  type        = string
}

variable "guardrail_version_description" {
  description = "Description for the guardrail version"
  type        = string
  default     = "Production version with enhanced security controls"
}

variable "guardrail_blocked_input_messaging" {
  description = "Message to display when input is blocked by the guardrail"
  type        = string
  default     = "This request violates the organization's AI usage policy. Please revise your input and try again."
}

variable "guardrail_blocked_outputs_messaging" {
  description = "Message to display when output is blocked by the guardrail"
  type        = string
  default     = "The generated response violates the organization's AI usage policy. Please try a different prompt."
}

variable "guardrail_kms_key_arn" {
  description = "ARN of an existing KMS key to use for encryption. If not provided, a new key will be created."
  type        = string
  default     = null
}

variable "guardrail_create_kms_key" {
  description = "Whether to create a new KMS key for guardrail encryption"
  type        = bool
  default     = true
}

variable "guardrail_kms_policy_json" {
  description = "Custom KMS key policy in JSON format"
  type        = string
  default     = null
}

variable "guardrail_kms_rotation_period_in_days" {
  description = "Rotation period for the KMS encryption key in days"
  type        = number
  default     = 90
}

variable "guardrail_kms_multi_region_key" {
  description = "Enable multi-region KMS key for cross-region disaster recovery"
  type        = bool
  default     = false
}

variable "guardrail_enable_pii_detection" {
  description = "Enable PII (Personally Identifiable Information) detection and blocking"
  type        = bool
  default     = true
}

variable "guardrail_pii_entities" {
  description = "List of PII entity types to detect and their actions (BLOCK or ANONYMIZE)"
  type = list(object({
    type   = string
    action = string
  }))
  default = [
    { type = "EMAIL", action = "BLOCK" },
    { type = "PHONE", action = "BLOCK" },
    { type = "NAME", action = "ANONYMIZE" },
    { type = "ADDRESS", action = "BLOCK" },
    { type = "AGE", action = "ANONYMIZE" },
    { type = "USERNAME", action = "ANONYMIZE" },
    { type = "PASSWORD", action = "BLOCK" },
    { type = "DRIVER_ID", action = "BLOCK" },
    { type = "LICENSE_PLATE", action = "BLOCK" },
    { type = "VEHICLE_IDENTIFICATION_NUMBER", action = "BLOCK" },
    { type = "CREDIT_DEBIT_CARD_CVV", action = "BLOCK" },
    { type = "CREDIT_DEBIT_CARD_EXPIRY", action = "BLOCK" },
    { type = "CREDIT_DEBIT_CARD_NUMBER", action = "BLOCK" },
    { type = "PIN", action = "BLOCK" },
    { type = "INTERNATIONAL_BANK_ACCOUNT_NUMBER", action = "BLOCK" },
    { type = "SWIFT_CODE", action = "BLOCK" },
    { type = "IP_ADDRESS", action = "ANONYMIZE" },
    { type = "MAC_ADDRESS", action = "ANONYMIZE" },
    { type = "AWS_ACCESS_KEY", action = "BLOCK" },
    { type = "AWS_SECRET_KEY", action = "BLOCK" },
    { type = "US_SOCIAL_SECURITY_NUMBER", action = "BLOCK" },
    { type = "US_PASSPORT_NUMBER", action = "BLOCK" },
    { type = "US_BANK_ACCOUNT_NUMBER", action = "BLOCK" },
    { type = "US_BANK_ROUTING_NUMBER", action = "BLOCK" }
  ]
}

variable "content_filters" {
  description = "Content filters to apply for harmful content detection"
  type = list(object({
    type            = string
    input_strength  = string
    output_strength = string
  }))
  default = [
    {
      type            = "HATE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    },
    {
      type            = "INSULTS"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    },
    {
      type            = "SEXUAL"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    },
    {
      type            = "VIOLENCE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    },
    {
      type            = "MISCONDUCT"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    },
    {
      type            = "PROMPT_ATTACK"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }
  ]
}

variable "denied_topics" {
  description = "List of topics to deny in conversations"
  type = list(object({
    name       = string
    definition = string
    examples   = list(string)
  }))
  default = []
}

variable "guardrail_denied_words" {
  description = "List of specific words or phrases to block"
  type        = list(string)
  default     = []
}

variable "guardrail_managed_word_lists" {
  description = "List of AWS managed word lists to apply (PROFANITY)"
  type        = list(string)
  default     = ["PROFANITY"]
}

variable "guardrail_contextual_grounding_filters" {
  description = "Contextual grounding filters to prevent hallucinations and ensure factual accuracy"
  type = list(object({
    type      = string
    threshold = number
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
