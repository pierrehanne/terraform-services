variable "project" {
  description = "Project name used for naming and organizing resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
}

variable "name" {
  description = "Repository name (appended to the project to form the repository, e.g. \"<project>/<name>\")"
  type        = string
}

//---------------------------------------------------------------------
// Image protection
//---------------------------------------------------------------------

variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten. IMMUTABLE (default) prevents tag reuse — recommended for reproducible deployments."
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["IMMUTABLE", "MUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be either IMMUTABLE or MUTABLE."
  }
}

variable "scan_on_push" {
  description = "Whether to scan images for vulnerabilities on push."
  type        = bool
  default     = true
}

variable "force_delete" {
  description = "Whether to delete the repository (and all images) even if it still contains images. Keep false in production."
  type        = bool
  default     = false
}

//---------------------------------------------------------------------
// Encryption
//---------------------------------------------------------------------

variable "encryption_type" {
  description = "Encryption for images at rest: \"KMS\" (creates a dedicated CMK unless kms_key_arn is set) or \"AES256\" (S3-managed)."
  type        = string
  default     = "KMS"

  validation {
    condition     = contains(["KMS", "AES256"], var.encryption_type)
    error_message = "encryption_type must be either KMS or AES256."
  }
}

variable "kms_key_arn" {
  description = "ARN of an existing KMS key to encrypt images. Only used when encryption_type = \"KMS\". When null, the module creates a dedicated key."
  type        = string
  default     = null
}

variable "kms_rotation_period_in_days" {
  description = "Rotation period for the dedicated KMS key (only when the module creates one)."
  type        = number
  default     = 90
}

//---------------------------------------------------------------------
// Lifecycle policy
//
// A sensible default keeps the last N tagged images and expires untagged
// images after a few days, so repositories don't grow unbounded. Set
// lifecycle_policy_json to override with a fully custom policy.
//---------------------------------------------------------------------

variable "max_tagged_image_count" {
  description = "Number of most-recent tagged images to retain. Older tagged images beyond this count are expired."
  type        = number
  default     = 20
}

variable "untagged_image_expiry_days" {
  description = "Number of days after which untagged images are expired."
  type        = number
  default     = 7
}

variable "lifecycle_policy_json" {
  description = "Fully custom ECR lifecycle policy (JSON). When set, it replaces the generated policy entirely."
  type        = string
  default     = null
}

//---------------------------------------------------------------------
// Repository (resource) policy
//
// Same-account access should be granted via IAM identity policies on the
// consumers. This escape hatch exists only for the rare case that genuinely
// needs a resource-based policy.
//---------------------------------------------------------------------

variable "repository_policy_json" {
  description = "Fully custom repository (resource) policy (JSON). When null (default), no repository policy is attached."
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
