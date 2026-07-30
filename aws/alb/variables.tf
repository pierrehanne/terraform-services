variable "project" {
  description = "Project name used for naming and organizing resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development). Deletion protection is enabled automatically in production."
  type        = string
}

variable "name" {
  description = "Load balancer name, used to build the ALB and related identifiers"
  type        = string
}

//---------------------------------------------------------------------
// Networking
//---------------------------------------------------------------------

variable "vpc_id" {
  description = "ID of the VPC the ALB and its target groups live in"
  type        = string
}

variable "internal" {
  description = "Whether the ALB is internal (no public IP). Recommended default for private workloads; set false only for internet-facing services."
  type        = bool
  default     = true
}

variable "subnet_ids" {
  description = "Subnet IDs the ALB is placed in. Use public subnets for an internet-facing ALB and private subnets for an internal one — at least two across different AZs."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least two subnets across different Availability Zones are required."
  }
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach the ALB on 443. Empty (default) creates no ingress rule — set explicitly (e.g. the VPC CIDR for an internal ALB, or wider for internet-facing)."
  type        = list(string)
  default     = []
}

//---------------------------------------------------------------------
// Listener / TLS
//---------------------------------------------------------------------

variable "certificate_arn" {
  description = "ARN of the ACM certificate for the HTTPS listener (from the dns module's certificate_arn)."
  type        = string
}

variable "ssl_policy" {
  description = "TLS security policy for the HTTPS listener."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "additional_certificate_arns" {
  description = "Extra ACM certificate ARNs to attach to the HTTPS listener (SNI) beyond the default certificate_arn."
  type        = list(string)
  default     = []
}

//---------------------------------------------------------------------
// Behaviour
//---------------------------------------------------------------------

variable "idle_timeout" {
  description = "Idle connection timeout in seconds."
  type        = number
  default     = 60
}

variable "enable_deletion_protection" {
  description = "Override deletion protection. When null (default) it is enabled automatically when environment == \"production\"."
  type        = bool
  default     = null
}

variable "access_logs_bucket" {
  description = "Optional S3 bucket name for ALB access logs. When null, access logging is disabled (enable it in production)."
  type        = string
  default     = null
}

variable "access_logs_prefix" {
  description = "Optional object-key prefix for ALB access logs within access_logs_bucket."
  type        = string
  default     = null
}

//---------------------------------------------------------------------
// Web Application Firewall (optional)
//---------------------------------------------------------------------

variable "enable_waf" {
  description = "Whether to attach a regional WAFv2 Web ACL to the ALB. Blocks common web exploits, known-bad inputs and abusive request rates by default."
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "Per-source-IP request threshold over a 5-minute window, above which the rate-based rule blocks. Only used when enable_waf is true."
  type        = number
  default     = 2000

  validation {
    condition     = var.waf_rate_limit >= 100 && var.waf_rate_limit <= 2000000000
    error_message = "waf_rate_limit must be between 100 and 2,000,000,000 (WAFv2 rate-based limits)."
  }
}

variable "waf_managed_rule_groups" {
  description = "Additional managed rule groups to append after the baseline, e.g. AWS SQL injection or IP-reputation sets. Set override_to_count to run a group in count (observe) mode instead of block."
  type = list(object({
    name              = string
    vendor_name       = optional(string, "AWS")
    priority          = number
    override_to_count = optional(bool, false)
  }))
  default = []

  validation {
    condition     = alltrue([for g in var.waf_managed_rule_groups : g.priority > 3])
    error_message = "Each waf_managed_rule_groups priority must be greater than 3 (priorities 1-3 are reserved for the baseline rules)."
  }
}

variable "tags" {
  description = "Common tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
