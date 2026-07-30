variable "project" {
  description = "Project name used for naming and organizing resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
}

variable "name" {
  description = "Name of the role, used to build the role and policy identifiers"
  type        = string
}

//---------------------------------------------------------------------
// Trust policy
//
// Provide the AWS service principals and/or IAM ARNs allowed to assume this
// role. Defaults to ECS tasks, the most common workload trust for this library.
//---------------------------------------------------------------------

variable "trusted_services" {
  description = "AWS service principals allowed to assume the role (e.g. [\"ecs-tasks.amazonaws.com\", \"lambda.amazonaws.com\"])."
  type        = list(string)
  default     = ["ecs-tasks.amazonaws.com"]
}

variable "trusted_role_arns" {
  description = "IAM role/user ARNs allowed to assume this role (for cross-account or human/CI access). Prefer explicit ARNs over account roots."
  type        = list(string)
  default     = []
}

variable "trust_conditions" {
  description = "Optional conditions applied to the AssumeRole statement (e.g. sts:ExternalId, aws:SourceArn). Keyed by condition operator."
  type = list(object({
    test     = string
    variable = string
    values   = list(string)
  }))
  default = []
}

//---------------------------------------------------------------------
// Permissions
//---------------------------------------------------------------------

variable "managed_policy_arns" {
  description = "ARNs of existing (AWS-managed or customer-managed) policies to attach to the role."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for a in var.managed_policy_arns : can(regex("^arn:aws[a-z-]*:iam::", a))])
    error_message = "Each managed_policy_arns entry must be a valid IAM policy ARN."
  }
}

variable "inline_policy_statements" {
  description = <<-EOT
    Least-privilege statements rendered into a single customer-managed policy and
    attached to the role. Prefer this over passing raw JSON: it is typed, validated,
    and keeps ARNs explicit. Leave empty to attach no custom policy.
  EOT
  type = list(object({
    sid       = optional(string)
    effect    = optional(string, "Allow")
    actions   = list(string)
    resources = list(string)
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))
  default = []

  validation {
    condition     = alltrue([for s in var.inline_policy_statements : contains(["Allow", "Deny"], s.effect)])
    error_message = "Each statement effect must be either \"Allow\" or \"Deny\"."
  }

  validation {
    condition     = alltrue([for s in var.inline_policy_statements : !contains(s.resources, "*") || s.effect == "Deny"])
    error_message = "Allow statements must not use \"*\" as a resource. Scope to explicit ARNs (least privilege). Use a Deny if a wildcard is truly intended."
  }
}

variable "policy_json" {
  description = "Escape hatch: a fully pre-rendered IAM policy document (JSON) to attach in addition to inline_policy_statements. Use only when the structured input cannot express the policy."
  type        = string
  default     = null
}

//---------------------------------------------------------------------
// Role behaviour
//---------------------------------------------------------------------

variable "max_session_duration" {
  description = "Maximum session duration (in seconds) for the role, between 3600 and 43200."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be between 3600 and 43200 seconds."
  }
}

variable "permissions_boundary_arn" {
  description = "Optional ARN of a policy set as the permissions boundary for the role."
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
