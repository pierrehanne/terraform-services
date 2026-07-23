locals {
  encryption_kms_alias = "alias/secretsmanager/${var.project}/${var.environment}/${var.secret_name}"
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
}

variable "project" {
  description = "Project name used for naming and organizing secrets"
  type        = string
}

variable "secret_name" {
  description = "Name of the secret to create in AWS Secrets Manager"
  type        = string
}

variable "secret_policy_json" {
  description = "Custom resource policy for the secret in JSON format"
  type        = string
  default     = null
}

variable "kms_policy_json" {
  description = "Custom KMS key policy in JSON format for encrypting the secret"
  type        = string
  default     = null
}

variable "recovery_window_in_days" {
  description = "Number of days to retain the secret before permanent deletion (0 for immediate deletion)"
  type        = number
  default     = 0
}

variable "kms_rotation_period_in_days" {
  description = "Rotation period for the KMS encryption key in days (90 days recommended for secrets)"
  type        = number
  default     = 90
}


variable "kms_multi_region_key" {
  description = "Enable multi-region KMS key for cross-region disaster recovery"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to the secret and KMS key resources"
  type        = map(string)
}
