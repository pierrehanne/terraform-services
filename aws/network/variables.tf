variable "project" {
  description = "Project name used for naming and organizing resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
}

variable "name" {
  description = "Name of the VPC, used to build resource identifiers"
  type        = string
}

variable "cidr_block" {
  description = "IPv4 CIDR block for the VPC (e.g. \"10.0.0.0/16\")"
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid IPv4 CIDR, e.g. \"10.0.0.0/16\"."
  }
}

variable "availability_zone_count" {
  description = "Number of Availability Zones to spread subnets across. Subnets are distributed round-robin over the first N AZs available in the region."
  type        = number
  default     = 2

  validation {
    condition     = var.availability_zone_count >= 1 && var.availability_zone_count <= 6
    error_message = "availability_zone_count must be between 1 and 6."
  }
}

//---------------------------------------------------------------------
// Subnets
//
// Subnets are supplied as CIDR lists. Each entry becomes one subnet,
// assigned round-robin to an Availability Zone and keyed by "<tier>-<index>"
// so reordering or extending the list never destroys existing subnets.
//
// - public  : routed to the Internet Gateway (only tier that can be public).
// - private : no direct Internet route. Reaches the Internet via NAT only
//             when nat_gateway != "none"; otherwise egress is via VPC endpoints.
//---------------------------------------------------------------------

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets. Leave empty for a fully private VPC (recommended default)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.public_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Every public_subnet_cidrs entry must be a valid IPv4 CIDR."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets. These host workloads (ECS, RDS, etc.) that should not be directly reachable from the Internet."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.private_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Every private_subnet_cidrs entry must be a valid IPv4 CIDR."
  }
}

//---------------------------------------------------------------------
// NAT
//---------------------------------------------------------------------

variable "nat_gateway" {
  description = "NAT strategy for private subnet egress: \"none\" (no Internet egress, rely on VPC endpoints — most secure and cheapest), \"single\" (one shared NAT gateway — cost-effective), or \"per_az\" (one NAT gateway per AZ — highly available)."
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "single", "per_az"], var.nat_gateway)
    error_message = "nat_gateway must be one of: none, single, per_az."
  }
}

//---------------------------------------------------------------------
// DNS
//---------------------------------------------------------------------

variable "enable_dns_hostnames" {
  description = "Whether instances receive public DNS hostnames. Required for interface VPC endpoints with private DNS."
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Whether DNS resolution is supported in the VPC. Required for VPC endpoints."
  type        = bool
  default     = true
}

//---------------------------------------------------------------------
// Flow logs
//---------------------------------------------------------------------

variable "enable_flow_logs" {
  description = "Whether to enable VPC Flow Logs to CloudWatch Logs. Recommended for security auditing (AWS Well-Architected)."
  type        = bool
  default     = true
}

variable "flow_logs_retention_in_days" {
  description = "Retention in days for the VPC Flow Logs CloudWatch Log Group."
  type        = number
  default     = 90
}

variable "flow_logs_traffic_type" {
  description = "Type of traffic to capture in flow logs: ALL, ACCEPT, or REJECT."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ALL", "ACCEPT", "REJECT"], var.flow_logs_traffic_type)
    error_message = "flow_logs_traffic_type must be one of: ALL, ACCEPT, REJECT."
  }
}

variable "flow_logs_kms_key_arn" {
  description = "Optional KMS key ARN to encrypt the flow logs CloudWatch Log Group. When null, logs use default CloudWatch encryption."
  type        = string
  default     = null
}

//---------------------------------------------------------------------
// VPC endpoints
//
// A baseline set of endpoints is always created for a private VPC (private
// subnets present) and cannot be disabled: the S3 gateway endpoint and the
// ecr.api / ecr.dkr / logs interface endpoints. Together they keep container
// image pulls and log delivery on PrivateLink so they never traverse a NAT
// gateway or the public Internet. The following flags add optional endpoints.
//---------------------------------------------------------------------

variable "enable_bedrock_endpoints" {
  description = "Create interface endpoints for Bedrock services (bedrock, bedrock-agent, bedrock-agent-runtime, bedrock-agentcore, bedrock-runtime)."
  type        = bool
  default     = false
}

variable "enable_cloudwatch_monitoring_endpoint" {
  description = "Create an interface endpoint for CloudWatch Metrics (monitoring). The Logs endpoint is always created as part of the baseline."
  type        = bool
  default     = false
}

variable "enable_dynamodb_endpoint" {
  description = "Create a gateway endpoint for DynamoDB."
  type        = bool
  default     = false
}

variable "enable_kms_endpoint" {
  description = "Create an interface endpoint for KMS."
  type        = bool
  default     = false
}

variable "enable_secretsmanager_endpoint" {
  description = "Create an interface endpoint for Secrets Manager."
  type        = bool
  default     = false
}

variable "enable_transcribe_endpoint" {
  description = "Create an interface endpoint for Transcribe."
  type        = bool
  default     = false
}

variable "cloudwatch_log_group_arns" {
  description = "Optional list of CloudWatch Log Group ARNs to scope the Logs endpoint policy to. When null or empty, the policy allows all log groups (still scoped to this VPC via aws:SourceVpc)."
  type        = list(string)
  default     = null
}

variable "dynamodb_table_arns" {
  description = "Optional list of DynamoDB table ARNs to scope the DynamoDB endpoint policy to. When null or empty, the policy allows all tables (still scoped to this VPC via aws:SourceVpc)."
  type        = list(string)
  default     = null
}

variable "tags" {
  description = "Common tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
