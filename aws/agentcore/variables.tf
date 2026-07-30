variable "project" {
  description = "Project name used for naming and organizing resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
}

variable "name" {
  description = "Agent name, used to build the runtime and related identifiers"
  type        = string
}

//---------------------------------------------------------------------
// Encryption
//---------------------------------------------------------------------

variable "kms_key_arn" {
  description = "ARN of the customer-managed KMS key (from the kms module) used to encrypt the Gateway, Memory and the credential token vault. Required whenever gateway, memory or identity.credential_providers are configured."
  type        = string
  default     = null
}

//---------------------------------------------------------------------
// Networking (security-by-design: the runtime runs in a VPC by default)
//---------------------------------------------------------------------

variable "subnet_ids" {
  description = "Private subnet IDs the runtime's ENIs are placed in. Required unless allow_public_network is true."
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Security group IDs attached to the runtime's ENIs. Required unless allow_public_network is true."
  type        = list(string)
  default     = []
}

variable "allow_public_network" {
  description = "Escape hatch to run the runtime in PUBLIC network mode instead of inside your VPC. Off by design — leave false to keep the runtime private."
  type        = bool
  default     = false
}

//---------------------------------------------------------------------
// Runtime (always created)
//---------------------------------------------------------------------

variable "runtime" {
  description = <<-EOT
    Runtime definition. Provide exactly one artifact:
      - container_uri: an ECR image URI, OR
      - code: { s3_bucket, s3_prefix, s3_version_id, entry_point, runtime } where
        runtime is one of PYTHON_3_10..PYTHON_3_13.
    server_protocol is HTTP | MCP | A2A | AGUI.
  EOT
  type = object({
    container_uri = optional(string)
    code = optional(object({
      s3_bucket     = string
      s3_prefix     = string
      s3_version_id = optional(string)
      entry_point   = list(string)
      runtime       = string
    }))
    server_protocol       = optional(string, "HTTP")
    environment_variables = optional(map(string), {})
    execution_role_arn    = optional(string) # created internally when null
  })

  validation {
    condition     = (var.runtime.container_uri != null) != (var.runtime.code != null)
    error_message = "Provide exactly one runtime artifact: either container_uri or code (not both, not neither)."
  }
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository the runtime image is pulled from. Used to scope the module-created execution role's ecr:BatchGetImage / GetDownloadUrlForLayer. Required when runtime.container_uri is set and no execution_role_arn is supplied."
  type        = string
  default     = null
}

variable "additional_execution_policy_statements" {
  description = "Extra least-privilege IAM statements added to the module-created runtime execution role (e.g. bedrock:InvokeModel on a specific model, S3 read on the code bucket)."
  type = list(object({
    sid       = optional(string)
    effect    = optional(string, "Allow")
    actions   = list(string)
    resources = list(string)
  }))
  default = []
}

//---------------------------------------------------------------------
// Inbound authentication (security-by-design: no unauthenticated runtime)
//---------------------------------------------------------------------

variable "jwt_authorizer" {
  description = "OIDC/JWT inbound authorizer for the runtime. Required unless allow_public_network is true (a private runtime still must authenticate callers). discovery_url is the OIDC discovery endpoint; scope access with allowed_audience / allowed_clients."
  type = object({
    discovery_url    = string
    allowed_audience = optional(list(string), [])
    allowed_clients  = optional(list(string), [])
    allowed_scopes   = optional(list(string), [])
  })
  default = null
}

variable "invoke_principal_arns" {
  description = "IAM principal ARNs allowed to invoke the runtime, enforced via an AgentCore resource policy. Empty creates no resource policy (rely on the JWT authorizer + IAM identity policies instead)."
  type        = list(string)
  default     = []
}

//---------------------------------------------------------------------
// Memory (optional)
//---------------------------------------------------------------------

variable "memory" {
  description = <<-EOT
    Optional AgentCore Memory. event_expiry_days governs short-term event
    retention (7-365). strategies configure long-term memory; each key is a
    strategy name and type is SEMANTIC | SUMMARIZATION | USER_PREFERENCE |
    EPISODIC. memory_execution_role_arn is required when any strategy uses model
    processing.
  EOT
  type = object({
    event_expiry_days         = optional(number, 90)
    memory_execution_role_arn = optional(string)
    strategies = optional(map(object({
      type       = string
      namespaces = optional(list(string), [])
    })), {})
  })
  default = null

  validation {
    condition     = var.memory == null || (var.memory.event_expiry_days >= 7 && var.memory.event_expiry_days <= 365)
    error_message = "memory.event_expiry_days must be between 7 and 365."
  }

  validation {
    condition = var.memory == null || alltrue([
      for k, s in var.memory.strategies : contains(["SEMANTIC", "SUMMARIZATION", "USER_PREFERENCE", "EPISODIC"], s.type)
    ])
    error_message = "Each memory strategy type must be SEMANTIC, SUMMARIZATION, USER_PREFERENCE, or EPISODIC."
  }
}

//---------------------------------------------------------------------
// Gateway (optional)
//---------------------------------------------------------------------

variable "gateway" {
  description = <<-EOT
    Optional AgentCore Gateway fronting tools as MCP. authorizer_type is
    CUSTOM_JWT or AWS_IAM. role_arn is the gateway's execution role. When
    authorizer_type is CUSTOM_JWT, jwt is required.
  EOT
  type = object({
    role_arn        = string
    authorizer_type = optional(string, "AWS_IAM")
    jwt = optional(object({
      discovery_url    = string
      allowed_audience = optional(list(string), [])
      allowed_clients  = optional(list(string), [])
      allowed_scopes   = optional(list(string), [])
    }))
    mcp_instructions = optional(string)
  })
  default = null

  validation {
    condition     = var.gateway == null || contains(["CUSTOM_JWT", "AWS_IAM"], var.gateway.authorizer_type)
    error_message = "gateway.authorizer_type must be CUSTOM_JWT or AWS_IAM."
  }

  validation {
    condition     = var.gateway == null || var.gateway.authorizer_type != "CUSTOM_JWT" || var.gateway.jwt != null
    error_message = "gateway.jwt is required when gateway.authorizer_type is CUSTOM_JWT."
  }
}

//---------------------------------------------------------------------
// Identity: outbound credential providers (optional)
//---------------------------------------------------------------------

variable "identity" {
  description = <<-EOT
    Optional Identity plane. workload_return_urls constrains OAuth2 return URLs
    for the agent's workload identity. credential_providers hold downstream
    (outbound) secrets in the token vault; secrets are supplied as write-only
    values (never stored in Terraform state). For each provider set exactly the
    secret matching its kind: oauth2 uses client_id_wo/client_secret_wo, api_key
    uses api_key_wo. Bump *_wo_version to rotate.
  EOT
  type = object({
    create_workload_identity = optional(bool, true)
    workload_return_urls     = optional(list(string), [])

    oauth2_providers = optional(map(object({
      vendor                        = string # CustomOauth2 | GithubOauth2 | GoogleOauth2 | MicrosoftOauth2 | SalesforceOauth2 | SlackOauth2
      client_id_wo                  = string
      client_secret_wo              = string
      client_credentials_wo_version = number
      discovery_url                 = optional(string)
    })), {})

    api_key_providers = optional(map(object({
      api_key_wo         = string
      api_key_wo_version = number
    })), {})
  })
  default = null
}

variable "tags" {
  description = "Common tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
