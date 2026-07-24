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
  description = "Rotation period for the KMS key"
  type        = number
  default     = 365
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
