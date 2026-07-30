variable "project" {
  description = "Project name used for naming and organizing resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
}

variable "name" {
  description = "Logical bucket name (combined with project to form the bucket name unless bucket_name is set)"
  type        = string
}

variable "bucket_name" {
  description = "Explicit, globally-unique bucket name. When null, defaults to \"<project>-<name>\". Bucket names must be globally unique across all of AWS."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Whether Terraform may delete the bucket even if it still contains objects. Keep false in production."
  type        = bool
  default     = false
}

//---------------------------------------------------------------------
// Encryption
//---------------------------------------------------------------------

variable "encryption_type" {
  description = "Server-side encryption: \"KMS\" (creates a dedicated CMK unless kms_key_arn is set) or \"AES256\" (S3-managed keys)."
  type        = string
  default     = "KMS"

  validation {
    condition     = contains(["KMS", "AES256"], var.encryption_type)
    error_message = "encryption_type must be either KMS or AES256."
  }
}

variable "kms_key_arn" {
  description = "ARN of an existing KMS key to encrypt objects. Only used when encryption_type = \"KMS\". When null, the module creates a dedicated key."
  type        = string
  default     = null
}

variable "kms_rotation_period_in_days" {
  description = "Rotation period for the dedicated KMS key (only when the module creates one)."
  type        = number
  default     = 90
}

//---------------------------------------------------------------------
// Versioning
//---------------------------------------------------------------------

variable "versioning_enabled" {
  description = "Whether object versioning is enabled. On by default to protect against accidental overwrite/deletion."
  type        = bool
  default     = true
}

//---------------------------------------------------------------------
// Lifecycle
//
// A single unified list of rules. Each rule can transition and/or expire both
// current and noncurrent versions and abort incomplete multipart uploads.
//---------------------------------------------------------------------

variable "lifecycle_rules" {
  description = "Lifecycle rules. Each rule may filter by prefix, transition current/noncurrent versions to other storage classes, expire them, and abort incomplete multipart uploads."
  type = list(object({
    id     = string
    prefix = optional(string)

    transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])

    expiration_days = optional(number)

    noncurrent_version_transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])

    noncurrent_version_expiration_days = optional(number)

    abort_incomplete_multipart_upload_days = optional(number, 7)
  }))
  default = []

  validation {
    condition = alltrue([
      for r in var.lifecycle_rules :
      length(r.transitions) > 0 ||
      r.expiration_days != null ||
      length(r.noncurrent_version_transitions) > 0 ||
      r.noncurrent_version_expiration_days != null ||
      r.abort_incomplete_multipart_upload_days != null
    ])
    error_message = "Each lifecycle rule must define at least one action (a transition, expiration, noncurrent rule, or abort-multipart)."
  }
}

//---------------------------------------------------------------------
// Access logging
//---------------------------------------------------------------------

variable "logging_target_bucket" {
  description = "Name of an existing bucket to receive S3 server access logs. When null, access logging is disabled."
  type        = string
  default     = null
}

variable "logging_target_prefix" {
  description = "Key prefix for delivered access logs in the target bucket."
  type        = string
  default     = null
}

//---------------------------------------------------------------------
// Bucket policy
//---------------------------------------------------------------------

variable "policy_json" {
  description = "Additional bucket policy statements (JSON) merged with the always-on TLS-only deny. Use for cross-account or service grants."
  type        = string
  default     = null
}

//---------------------------------------------------------------------
// Cross-region replication (optional)
//---------------------------------------------------------------------

variable "replication_role_arn" {
  description = "ARN of the IAM role S3 assumes to replicate objects. Required to enable replication; when null, replication is disabled."
  type        = string
  default     = null
}

variable "replication_rules" {
  description = "Replication rules. Each targets a destination bucket ARN, optionally under a prefix, with a storage class and optional destination KMS key."
  type = list(object({
    id                      = string
    prefix                  = optional(string)
    destination_bucket_arn  = string
    storage_class           = optional(string, "STANDARD")
    destination_kms_key_arn = optional(string)
    priority                = optional(number)
  }))
  default = []
}

//---------------------------------------------------------------------
// Glue / Athena integration (optional, all off by default)
//---------------------------------------------------------------------

variable "enable_glue_database" {
  description = "Whether to create a Glue Catalog database for this bucket's data."
  type        = bool
  default     = false
}

variable "glue_database_name" {
  description = "Name of the Glue Catalog database. Defaults to \"<project>_<name>\" (hyphens replaced with underscores) when null."
  type        = string
  default     = null
}

variable "enable_glue_crawler" {
  description = "Whether to create a Glue Crawler that catalogs this bucket. Requires enable_glue_database and glue_crawler_role_arn."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_glue_crawler || var.enable_glue_database
    error_message = "enable_glue_crawler requires enable_glue_database to be true."
  }
}

variable "glue_crawler_role_arn" {
  description = "ARN of the IAM role the Glue Crawler assumes (needs read access to the bucket and Glue catalog write). Required when enable_glue_crawler is true."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_glue_crawler || var.glue_crawler_role_arn != null
    error_message = "glue_crawler_role_arn is required when enable_glue_crawler is true."
  }
}

variable "glue_crawler_s3_path" {
  description = "S3 path the crawler scans, e.g. \"s3://my-bucket/data/\". Defaults to the bucket root when null."
  type        = string
  default     = null
}

variable "glue_crawler_schedule" {
  description = "Cron schedule for the crawler (e.g. \"cron(0 2 * * ? *)\"). When null, the crawler runs on demand only."
  type        = string
  default     = null
}

variable "enable_athena_workgroup" {
  description = "Whether to create an Athena workgroup with query results written to this bucket (encrypted)."
  type        = bool
  default     = false
}

variable "athena_results_prefix" {
  description = "Key prefix under which Athena query results are stored in this bucket."
  type        = string
  default     = "athena-results/"
}

variable "tags" {
  description = "Common tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
