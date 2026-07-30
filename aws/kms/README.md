# KMS

A deliberately minimal primitive that provisions a single customer-managed KMS
key and a companion alias. It exists to be consumed by higher-level modules
(`ecr`, `storage`, `secrets-manager`, `aurora-postgresql`, `lambda-layers`)
rather than wired up as a standalone stack.

## Design principles

- **Single key + alias** — one `aws_kms_key` and one `aws_kms_alias`, nothing
  more. This module intentionally stays a low-level building block.
- **Rotation on by default** — `enable_key_rotation` defaults to `true` with a
  365-day `rotation_period_in_days` (tunable within the 90–2560 range).
- **Optional custom key policy** — pass `kms_policy` to attach a bespoke policy;
  leave it unset to fall back to the AWS default key policy.
- **Composable, not opinionated** — no `project`/`environment`/`name` inputs.
  Callers own naming (via `alias`) and tagging so the key slots cleanly into any
  consuming module.

## Usage

```hcl
module "storage_kms" {
  source = "../kms"

  alias               = "alias/app-storage"
  description         = "Encryption key for the app-storage bucket"
  enable_key_rotation = true
  multi_region        = false

  tags = { ManagedBy = "terraform" }
}
```

- [`examples/simple`](./examples/simple) — one key with an alias and tags.

## Notes

- `alias` must include the full `alias/` prefix expected by the AWS API.
- `rotation_period_in_days` only applies when `enable_key_rotation = true`;
  otherwise it is ignored.
- Set `multi_region = true` to create a multi-region primary key when the
  consuming workload spans regions.
- Because the resource addresses use the repo's `this` convention, `moved.tf`
  blocks are included to migrate any pre-existing state addresses in place.

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docs will populate inputs/outputs here on pre-commit -->
<!-- END_TF_DOCS -->
