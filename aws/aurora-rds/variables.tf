variable "project" {
  description = "Project name used for naming and organizing resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
}

variable "name" {
  description = "Name of the Aurora PostgreSQL cluster, used to build resource identifiers"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the cluster and its security group will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group, must cover at least 2 AZs"
  type        = list(string)
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version (e.g. \"16.6\"). The parameter group family is derived automatically from the major version."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+", var.engine_version))
    error_message = "engine_version must be in the form \"<major>.<minor>\", e.g. \"16.6\"."
  }
}

variable "database_name" {
  description = "Name of the default database created in the cluster. Defaults to the cluster name with hyphens replaced by underscores."
  type        = string
  default     = null
}

variable "master_username" {
  description = "Master username for the cluster. The password is generated automatically and stored in Secrets Manager."
  type        = string
  default     = "dbadmin"
}

//---------------------------------------------------------------------
// Networking / access
//---------------------------------------------------------------------

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to connect to the cluster on the PostgreSQL port"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to the cluster on the PostgreSQL port"
  type        = list(string)
  default     = []
}

variable "publicly_accessible" {
  description = "Whether the cluster instances get public IP addresses"
  type        = bool
  default     = false
}

//---------------------------------------------------------------------
// Serverless v2 capacity
//---------------------------------------------------------------------

variable "instance_count" {
  description = "Number of Serverless v2 instances in the cluster (Aurora elects one writer automatically)"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1
    error_message = "instance_count must be at least 1."
  }
}

variable "min_capacity" {
  description = "Minimum Aurora Capacity Units (ACUs). Set to 0 to allow the cluster to auto-pause (requires seconds_until_auto_pause)."
  type        = number
  default     = 0.5
}

variable "max_capacity" {
  description = "Maximum Aurora Capacity Units (ACUs)"
  type        = number
  default     = 1
}

variable "seconds_until_auto_pause" {
  description = "Seconds of inactivity before the cluster auto-pauses. Only applied when min_capacity is 0."
  type        = number
  default     = null
}

//---------------------------------------------------------------------
// Parameter groups
//---------------------------------------------------------------------

variable "cluster_parameters" {
  description = "DB cluster parameters to apply"
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "pending-reboot")
  }))
  default = []
}

variable "instance_parameters" {
  description = "DB instance parameters to apply"
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "pending-reboot")
  }))
  default = []
}

//---------------------------------------------------------------------
// Backups / maintenance / protection
//---------------------------------------------------------------------

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Daily time range during which backups happen (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "preferred_maintenance_window" {
  description = "Weekly time range during which system maintenance can occur (UTC)"
  type        = string
  default     = "sun:04:30-sun:05:30"
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection on the cluster"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot when the cluster is destroyed"
  type        = bool
  default     = false
}

variable "apply_immediately" {
  description = "Whether cluster/instance modifications are applied immediately instead of during the next maintenance window"
  type        = bool
  default     = false
}

variable "allow_major_version_upgrade" {
  description = "Whether to allow major engine version upgrades"
  type        = bool
  default     = false
}

variable "auto_minor_version_upgrade" {
  description = "Whether minor engine upgrades are applied automatically during the maintenance window"
  type        = bool
  default     = true
}

variable "enabled_cloudwatch_logs_exports" {
  description = "Log types to export to CloudWatch. Aurora PostgreSQL only supports \"postgresql\"."
  type        = list(string)
  default     = ["postgresql"]
}

variable "performance_insights_enabled" {
  description = "Whether to enable Performance Insights on cluster instances (encrypted with the cluster's KMS key)"
  type        = bool
  default     = true
}

//---------------------------------------------------------------------
// Encryption / secrets
//---------------------------------------------------------------------

variable "kms_rotation_period_in_days" {
  description = "Rotation period for the storage-encryption KMS key"
  type        = number
  default     = 90
}

variable "secret_recovery_window_in_days" {
  description = "Number of days to retain the master-credentials secret before permanent deletion (0 for immediate deletion)"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Common tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
