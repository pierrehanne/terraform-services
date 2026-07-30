// A Cognito user pool, hosted-UI domain and app client sized for use as an ALB
// authenticate-cognito identity provider. Secure by default: strong password
// policy, email as the sign-in alias, admin-only user creation, deletion
// protection, and short-lived tokens. SAML/OIDC federation is intentionally
// out of scope for this module.

locals {
  name_prefix = "${var.project}-${var.name}"

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
    },
    var.tags
  )
}

//---------------------------------------------------------------------
// User pool
//---------------------------------------------------------------------

resource "aws_cognito_user_pool" "this" {
  name = local.name_prefix

  # Sign in with email.
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = var.password_minimum_length
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  admin_create_user_config {
    allow_admin_create_user_only = var.allow_admin_create_user_only
  }

  mfa_configuration = var.mfa_configuration

  dynamic "software_token_mfa_configuration" {
    for_each = var.mfa_configuration == "OFF" ? [] : [1]
    content {
      enabled = true
    }
  }

  # Surface a generic error on unknown users to avoid account enumeration.
  # (Configured on the client via prevent_user_existence_errors.)

  deletion_protection = var.deletion_protection ? "ACTIVE" : "INACTIVE"

  tags = local.common_tags
}

//---------------------------------------------------------------------
// Hosted UI domain
//---------------------------------------------------------------------

resource "aws_cognito_user_pool_domain" "this" {
  domain       = var.domain_prefix
  user_pool_id = aws_cognito_user_pool.this.id
}

//---------------------------------------------------------------------
// App client (used by the ALB authenticate-cognito action)
//---------------------------------------------------------------------

resource "aws_cognito_user_pool_client" "this" {
  name         = "${local.name_prefix}-client"
  user_pool_id = aws_cognito_user_pool.this.id

  # The ALB requires a confidential client (client secret).
  generate_secret = true

  explicit_auth_flows = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = var.allowed_oauth_scopes
  supported_identity_providers         = ["COGNITO"]

  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls

  access_token_validity  = var.access_token_validity_hours
  id_token_validity      = var.id_token_validity_hours
  refresh_token_validity = var.refresh_token_validity_hours

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "hours"
  }

  prevent_user_existence_errors = "ENABLED"
}

//---------------------------------------------------------------------
// Groups
//---------------------------------------------------------------------

resource "aws_cognito_user_group" "this" {
  for_each = toset(var.user_groups)

  name         = each.key
  user_pool_id = aws_cognito_user_pool.this.id
}
