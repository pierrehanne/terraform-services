variable "project" {
  description = "Project name used for naming and organizing resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
}

variable "name" {
  description = "Pool name, used to build the user pool and client identifiers"
  type        = string
}

//---------------------------------------------------------------------
// Hosted UI domain
//---------------------------------------------------------------------

variable "domain_prefix" {
  description = "Prefix for the Cognito-hosted login domain (https://<prefix>.auth.<region>.amazoncognito.com). Must be globally unique, lowercase, and DNS-safe (letters, digits, hyphens)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$", var.domain_prefix))
    error_message = "domain_prefix must be 1-63 characters, lowercase alphanumeric or hyphen, and must not start or end with a hyphen."
  }
}

//---------------------------------------------------------------------
// App client (wired to the ALB authenticate-cognito action)
//---------------------------------------------------------------------

variable "callback_urls" {
  description = "Allowed OAuth callback (redirect) URLs. For ALB authentication use https://<app-domain>/oauth2/idpresponse. All entries must be HTTPS."
  type        = list(string)

  validation {
    condition     = length(var.callback_urls) > 0
    error_message = "At least one callback URL is required."
  }

  validation {
    condition     = alltrue([for u in var.callback_urls : startswith(u, "https://")])
    error_message = "All callback_urls must be HTTPS."
  }
}

variable "logout_urls" {
  description = "Allowed sign-out redirect URLs. All entries must be HTTPS."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for u in var.logout_urls : startswith(u, "https://")])
    error_message = "All logout_urls must be HTTPS."
  }
}

variable "allowed_oauth_scopes" {
  description = "OAuth scopes granted to the app client. Defaults to the scopes the ALB authenticate-cognito action expects."
  type        = list(string)
  default     = ["openid", "email", "profile"]
}

variable "access_token_validity_hours" {
  description = "Access token lifetime in hours."
  type        = number
  default     = 1
}

variable "id_token_validity_hours" {
  description = "ID token lifetime in hours."
  type        = number
  default     = 1
}

variable "refresh_token_validity_hours" {
  description = "Refresh token lifetime in hours."
  type        = number
  default     = 24
}

//---------------------------------------------------------------------
// Security posture
//---------------------------------------------------------------------

variable "password_minimum_length" {
  description = "Minimum password length enforced by the user pool."
  type        = number
  default     = 12

  validation {
    condition     = var.password_minimum_length >= 8
    error_message = "password_minimum_length must be at least 8 (Cognito minimum); 12+ is recommended."
  }
}

variable "mfa_configuration" {
  description = "MFA enforcement: OFF, ON (required for all users) or OPTIONAL. Software TOTP is enabled whenever this is not OFF."
  type        = string
  default     = "OPTIONAL"

  validation {
    condition     = contains(["OFF", "ON", "OPTIONAL"], var.mfa_configuration)
    error_message = "mfa_configuration must be one of OFF, ON, or OPTIONAL."
  }
}

variable "allow_admin_create_user_only" {
  description = "When true, only administrators can create users (self sign-up is disabled). Recommended for internal ALB-fronted applications."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection on the user pool."
  type        = bool
  default     = true
}

//---------------------------------------------------------------------
// Groups
//---------------------------------------------------------------------

variable "user_groups" {
  description = "User pool groups to create (e.g. [\"admins\", \"readers\"]) for coarse-grained authorization."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
