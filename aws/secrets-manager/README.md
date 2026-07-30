# Secrets Manager

A thin, secure-by-default wrapper that provisions an AWS Secrets Manager secret
"shell" encrypted with its own dedicated KMS key. The module creates the secret
container and the key; the caller is responsible for writing the secret value
(the version), keeping sensitive material out of this module's state and inputs.

## Design principles

- **Secret shell only** — the module creates the `aws_secretsmanager_secret`
  container. It never writes a `secret_version`, so no secret material passes
  through this module's variables or state. The caller owns the value.
- **Dedicated KMS key** — encryption uses a per-secret CMK provisioned through
  the shared [`../kms`](../kms) module, with a predictable alias
  (`alias/secretsmanager/<project>/<environment>/<secret_name>`) and rotation
  enabled (90 days by default).
- **Least-privilege, optional policies** — both the secret resource policy
  (`secret_policy_json`) and the KMS key policy (`kms_policy_json`) are optional
  and default to `null`, so you attach only the access you need.

## Usage

```hcl
module "app_secret" {
  source = "../secrets-manager"

  project     = "acme"
  environment = "production"
  secret_name = "app-db-credentials"

  recovery_window_in_days = 7

  tags = { ManagedBy = "terraform" }
}
```

- [`examples/simple`](./examples/simple) — a secret shell with a dedicated KMS key.

## Notes

- The `encrypted_secret` output exposes the secret's `id`, `name`, `arn`, and a
  nested `kms` object (`id`, `arn`, `alias`, `alias_arn`). Downstream modules
  (e.g. `aurora-postgresql`) depend on this name and shape — keep it stable.
- Write the secret value in the caller using `aws_secretsmanager_secret_version`
  targeting `module.<name>.encrypted_secret.id`.
- `recovery_window_in_days = 0` deletes the secret immediately on destroy (no
  recovery window); use a non-zero window in production.
- Set `kms_multi_region_key = true` for cross-region disaster recovery.

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docs will populate inputs/outputs here on pre-commit -->
<!-- END_TF_DOCS -->
