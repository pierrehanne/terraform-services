variable "project" {
  description = "Project name used for naming and organizing resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
}

variable "name" {
  description = "Cluster name, used to build the cluster and per-service identifiers"
  type        = string
}

//---------------------------------------------------------------------
// Networking
//---------------------------------------------------------------------

variable "vpc_id" {
  description = "ID of the VPC the services run in"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs the ECS tasks run in (from the network module's private_subnet_ids)"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) > 0
    error_message = "At least one private subnet is required."
  }
}

//---------------------------------------------------------------------
// Cluster
//---------------------------------------------------------------------

variable "enable_container_insights" {
  description = "Whether to enable CloudWatch Container Insights on the cluster for observability."
  type        = bool
  default     = true
}

variable "capacity_provider_strategy" {
  description = "Default cluster capacity provider strategy. Each entry weights FARGATE vs FARGATE_SPOT. Defaults to 100% on-demand FARGATE for predictable production behaviour."
  type = list(object({
    capacity_provider = string
    weight            = number
    base              = optional(number)
  }))
  default = [{
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }]

  validation {
    condition     = alltrue([for c in var.capacity_provider_strategy : contains(["FARGATE", "FARGATE_SPOT"], c.capacity_provider)])
    error_message = "capacity_provider must be FARGATE or FARGATE_SPOT."
  }
}

variable "log_retention_in_days" {
  description = "Retention in days for the per-service CloudWatch Log Groups."
  type        = number
  default     = 30
}

variable "log_kms_key_arn" {
  description = "Optional KMS key ARN to encrypt the CloudWatch Log Groups. When null, logs use default CloudWatch encryption."
  type        = string
  default     = null
}

//---------------------------------------------------------------------
// ALB attachment (the ALB itself is created by the `alb` module)
//---------------------------------------------------------------------

variable "alb_listener_arn" {
  description = "ARN of an existing HTTPS listener (from the alb module's https_listener_arn) to attach per-service target groups and listener rules to. Required when any service sets alb.enabled = true; leave null for services with no load balancer."
  type        = string
  default     = null
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB (from the alb module's alb_security_group_id). Services that attach to the ALB allow ingress from this security group. Required when alb_listener_arn is set."
  type        = string
  default     = null

  validation {
    condition     = var.alb_listener_arn == null || var.alb_security_group_id != null
    error_message = "alb_security_group_id is required when alb_listener_arn is set (services need to allow ingress from the ALB's security group)."
  }
}

//---------------------------------------------------------------------
// Services
//
// A map of service name => definition. One module instance runs many
// independent services, each with its own image, sizing, IAM, secrets,
// autoscaling and (optionally) ALB target.
//---------------------------------------------------------------------

variable "services" {
  description = "Map of ECS Fargate services to create, keyed by service name."
  type = map(object({
    # Container
    image   = string
    cpu     = optional(number, 256)
    memory  = optional(number, 512)
    command = optional(list(string))
    port    = optional(number) # container port; required if the service is behind the ALB

    # Container hardening. readonly_root_filesystem defaults on; set a non-root
    # user (e.g. "1000") where the image supports it.
    readonly_root_filesystem = optional(bool, true)
    user                     = optional(string)

    environment = optional(map(string), {})

    # Secrets injected as env vars. Map of ENV_VAR_NAME => Secrets Manager /
    # SSM Parameter ARN. The execution role is granted read + KMS decrypt on these.
    secrets = optional(map(string), {})

    # Desired running tasks (ignored when autoscaling manages the count).
    desired_count = optional(number, 1)

    # Enable ECS Exec (SSM shell into tasks). Off by default; turn on only for
    # debugging and grant the task role SSM messages permissions.
    enable_execute_command = optional(bool, false)

    # Task role permissions (application permissions). Least-privilege statements.
    task_policy_statements = optional(list(object({
      sid       = optional(string)
      effect    = optional(string, "Allow")
      actions   = list(string)
      resources = list(string)
    })), [])

    # KMS keys the execution role may decrypt for secrets (in addition to any
    # inferred from the secret ARNs). Explicit ARNs only.
    secret_kms_key_arns = optional(list(string), [])

    # Autoscaling (target tracking on CPU/memory)
    autoscaling = optional(object({
      min_capacity       = number
      max_capacity       = number
      cpu_target         = optional(number, 70)
      memory_target      = optional(number)
      scale_in_cooldown  = optional(number, 300)
      scale_out_cooldown = optional(number, 60)
    }))

    # ALB attachment. Set authenticate_cognito to put a Cognito login in front
    # of the service (wire the cognito module's outputs into it).
    alb = optional(object({
      enabled              = bool
      path_patterns        = optional(list(string), ["/*"])
      priority             = number
      health_check_path    = optional(string, "/")
      health_check_matcher = optional(string, "200")
      authenticate_cognito = optional(object({
        user_pool_arn       = string
        user_pool_client_id = string
        user_pool_domain    = string
        scope               = optional(string, "openid email profile")
        session_timeout     = optional(number, 3600)
      }))
    }))

    # Allow the service's tasks to receive traffic from these security groups
    # directly (e.g. another service), on the container port.
    ingress_security_group_ids = optional(list(string), [])
  }))
  default = {}

  validation {
    condition     = alltrue([for k, s in var.services : contains([256, 512, 1024, 2048, 4096, 8192, 16384], s.cpu)])
    error_message = "Each service cpu must be a valid Fargate value: 256, 512, 1024, 2048, 4096, 8192, or 16384."
  }

  validation {
    condition     = alltrue([for k, s in var.services : s.alb == null || !try(s.alb.enabled, false) || s.port != null])
    error_message = "A service with alb.enabled = true must set a container port."
  }
}

variable "tags" {
  description = "Common tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
