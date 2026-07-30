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
<!-- terraform-docs will populate inputs/outputs here on pre-commit -->
<!-- END_TF_DOCS -->
