# Cognito

A Cognito user pool, hosted-UI domain and app client sized for use as an
Application Load Balancer identity provider (the `authenticate-cognito` listener
action). Secure by default and intentionally minimal — SAML/OIDC federation is
out of scope for this version.

The four outputs (`user_pool_arn`, `user_pool_client_id`, `user_pool_domain`,
plus `user_pool_id`) are exactly what the `alb` module's per-rule
`authenticate_cognito` block consumes.

## Design principles

- **ALB-ready client** — a confidential client (`generate_secret = true`), the
  `code` OAuth flow and `openid email profile` scopes, which is what the ALB
  `authenticate-cognito` action requires.
- **Secure defaults** — email sign-in, 12-character password minimum requiring
  all character classes, admin-only user creation, deletion protection, TOTP
  MFA (`OPTIONAL` by default, set `ON` to require it), user-existence errors
  suppressed to prevent account enumeration, and short-lived access/ID tokens.
- **Coarse-grained groups** — declare `user_groups` for simple authorization
  tiers.

## Usage

```hcl
module "cognito" {
  source = "../cognito"

  project     = "acme"
  environment = "production"
  name        = "web"

  domain_prefix = "acme-web-prod"
  callback_urls = ["https://app.prod.example.com/oauth2/idpresponse"]
  logout_urls   = ["https://app.prod.example.com/logout"]

  mfa_configuration = "ON"
  user_groups       = ["admins", "readers"]

  tags = { ManagedBy = "terraform" }
}
```

- [`examples/alb-auth`](./examples/alb-auth) — a pool wired for ALB
  authentication.

## Notes

- `callback_urls` for ALB authentication must be `https://<app-domain>/oauth2/idpresponse`
  — the reserved path the ALB uses to complete the OAuth code exchange.
- `domain_prefix` must be globally unique across all AWS accounts in the region.
- The app client has a secret; the ALB reads it directly via the
  `authenticate-cognito` action, so it does not need to be exported.
- To require MFA for everyone set `mfa_configuration = "ON"`; `OPTIONAL` lets
  users enroll TOTP themselves.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.15 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.57 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.57 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cognito_user_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_group) | resource |
| [aws_cognito_user_pool.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool) | resource |
| [aws_cognito_user_pool_client.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client) | resource |
| [aws_cognito_user_pool_domain.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_domain) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_token_validity_hours"></a> [access\_token\_validity\_hours](#input\_access\_token\_validity\_hours) | Access token lifetime in hours. | `number` | `1` | no |
| <a name="input_allow_admin_create_user_only"></a> [allow\_admin\_create\_user\_only](#input\_allow\_admin\_create\_user\_only) | When true, only administrators can create users (self sign-up is disabled). Recommended for internal ALB-fronted applications. | `bool` | `true` | no |
| <a name="input_allowed_oauth_scopes"></a> [allowed\_oauth\_scopes](#input\_allowed\_oauth\_scopes) | OAuth scopes granted to the app client. Defaults to the scopes the ALB authenticate-cognito action expects. | `list(string)` | <pre>[<br/>  "openid",<br/>  "email",<br/>  "profile"<br/>]</pre> | no |
| <a name="input_callback_urls"></a> [callback\_urls](#input\_callback\_urls) | Allowed OAuth callback (redirect) URLs. For ALB authentication use https://<app-domain>/oauth2/idpresponse. All entries must be HTTPS. | `list(string)` | n/a | yes |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Whether to enable deletion protection on the user pool. | `bool` | `true` | no |
| <a name="input_domain_prefix"></a> [domain\_prefix](#input\_domain\_prefix) | Prefix for the Cognito-hosted login domain (https://<prefix>.auth.<region>.amazoncognito.com). Must be globally unique, lowercase, and DNS-safe (letters, digits, hyphens). | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., production, staging, development) | `string` | n/a | yes |
| <a name="input_id_token_validity_hours"></a> [id\_token\_validity\_hours](#input\_id\_token\_validity\_hours) | ID token lifetime in hours. | `number` | `1` | no |
| <a name="input_logout_urls"></a> [logout\_urls](#input\_logout\_urls) | Allowed sign-out redirect URLs. All entries must be HTTPS. | `list(string)` | `[]` | no |
| <a name="input_mfa_configuration"></a> [mfa\_configuration](#input\_mfa\_configuration) | MFA enforcement: OFF, ON (required for all users) or OPTIONAL. Software TOTP is enabled whenever this is not OFF. | `string` | `"OPTIONAL"` | no |
| <a name="input_name"></a> [name](#input\_name) | Pool name, used to build the user pool and client identifiers | `string` | n/a | yes |
| <a name="input_password_minimum_length"></a> [password\_minimum\_length](#input\_password\_minimum\_length) | Minimum password length enforced by the user pool. | `number` | `12` | no |
| <a name="input_project"></a> [project](#input\_project) | Project name used for naming and organizing resources | `string` | n/a | yes |
| <a name="input_refresh_token_validity_hours"></a> [refresh\_token\_validity\_hours](#input\_refresh\_token\_validity\_hours) | Refresh token lifetime in hours. | `number` | `24` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags applied to all resources created by this module | `map(string)` | `{}` | no |
| <a name="input_user_groups"></a> [user\_groups](#input\_user\_groups) | User pool groups to create (e.g. ["admins", "readers"]) for coarse-grained authorization. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_user_pool_arn"></a> [user\_pool\_arn](#output\_user\_pool\_arn) | ARN of the Cognito user pool (feed into the ALB authenticate-cognito action's user\_pool\_arn) |
| <a name="output_user_pool_client_id"></a> [user\_pool\_client\_id](#output\_user\_pool\_client\_id) | ID of the app client (feed into the ALB authenticate-cognito action's user\_pool\_client\_id) |
| <a name="output_user_pool_domain"></a> [user\_pool\_domain](#output\_user\_pool\_domain) | Hosted-UI domain prefix (feed into the ALB authenticate-cognito action's user\_pool\_domain) |
| <a name="output_user_pool_endpoint"></a> [user\_pool\_endpoint](#output\_user\_pool\_endpoint) | Endpoint of the user pool (e.g. cognito-idp.<region>.amazonaws.com/<pool-id>) |
| <a name="output_user_pool_id"></a> [user\_pool\_id](#output\_user\_pool\_id) | ID of the Cognito user pool |
<!-- END_TF_DOCS -->
