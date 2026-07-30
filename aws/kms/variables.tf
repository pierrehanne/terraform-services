variable "alias" {
  description = "KMS alias without the alias/ project."
  type        = string
}

variable "description" {
  description = "Description of the KMS key."
  type        = string
}

variable "enable_key_rotation" {
  description = "Enable automatic yearly key rotation."
  type        = bool
  default     = true
}

variable "multi_region" {
  description = "Whether the KMS key is multi-region."
  type        = bool
  default     = false
}

variable "kms_rotation_period_in_days" {
  description = "Rotation period in days for the KMS key when rotation is enabled (valid range 90-2560)."
  type        = number
  default     = 365

  validation {
    condition     = var.kms_rotation_period_in_days >= 90 && var.kms_rotation_period_in_days <= 2560
    error_message = "kms_rotation_period_in_days must be between 90 and 2560."
  }
}

variable "kms_policy" {
  description = "Provide custom policy for KMS"
  type        = string
  default     = null
}


variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
