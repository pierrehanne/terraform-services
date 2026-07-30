# Aurora PostgreSQL

An opinionated Aurora PostgreSQL **Serverless v2** cluster with secure defaults.
It provisions the cluster, one or more `db.serverless` instances, cluster and
instance parameter groups, a dedicated security group, and wires in a
customer-managed KMS key and a Secrets Manager secret for the master
credentials — so a caller gets a production-shaped database from a handful of
inputs.

## Design principles

- **Serverless v2 autoscaling** — instances run on `db.serverless` and scale
  between `min_capacity` and `max_capacity` ACUs. Set `min_capacity = 0` to let
  the cluster auto-pause after `seconds_until_auto_pause` of inactivity.
- **Encryption via the shared `kms` module** — storage and Performance Insights
  are encrypted with a customer-managed key created by the reusable `../kms`
  module, aliased per project/environment/cluster.
- **Master credentials in the `secrets-manager` module** — the password is
  generated with `random_password` and stored as a JSON secret (engine, host,
  reader, port, dbname, username, password) via the reusable
  `../secrets-manager` module. The password is never surfaced as an output.
- **Deletion protection on by default** — `deletion_protection = true` and a
  final snapshot is taken on destroy unless `skip_final_snapshot` is set.
- **Private-only by default** — `publicly_accessible = false`; access is granted
  explicitly through `allowed_security_group_ids` / `allowed_cidr_blocks` on the
  cluster's own security group.
- **Performance Insights on** — enabled by default and encrypted with the
  cluster's KMS key.

## Usage

```hcl
module "aurora" {
  source = "../aurora-postgresql"

  project     = "acme"
  environment = "production"
  name        = "orders"

  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = ["subnet-aaa", "subnet-bbb"]

  engine_version = "16.6"

  min_capacity = 0.5
  max_capacity = 4

  allowed_security_group_ids = ["sg-0123456789abcdef0"]

  tags = { ManagedBy = "terraform" }
}
```

## Composition

This module is a higher-level building block that reuses two lower-level
primitives in the repo:

- [`../kms`](../kms) — the customer-managed key used for storage and Performance
  Insights encryption.
- [`../secrets-manager`](../secrets-manager) — the encrypted secret holding the
  master credentials.

Both receive the module's `common_tags` (which stamp `Project` and
`Environment`) so the key and secret carry the same tagging as the cluster.

- [`examples/simple`](./examples/simple) — a minimal cluster in an existing VPC.

## Notes

- `engine_version` must be `"<major>.<minor>"` (e.g. `"16.6"`); the parameter
  group family (`aurora-postgresql<major>`) is derived from the major version.
- `subnet_ids` must span at least two Availability Zones.
- `seconds_until_auto_pause` is only applied when `min_capacity = 0`.
- `database_name` defaults to the cluster `name` with hyphens replaced by
  underscores.
- The security group resource uses the repo's `this` convention; a `moved.tf`
  block migrates any pre-existing `aws_security_group.aurora` state address in
  place.

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docs will populate inputs/outputs here on pre-commit -->
<!-- END_TF_DOCS -->
