# Storage

A secure-by-default S3 bucket built on the modern (provider v4+) split-resource
API, with an optional Glue + Athena analytics stack.

## Design principles

Security is not optional in this module — the following are **always on** and
cannot be disabled:

- **Block Public Access** — all four flags enabled.
- **Encryption at rest** — SSE-KMS with a dedicated key by default (or bring your
  own key / opt down to `AES256`). A bucket key reduces KMS cost.
- **TLS-only** — a bucket policy denies any request where
  `aws:SecureTransport = false`.
- **ACLs disabled** — `BucketOwnerEnforced` ownership; the bucket owner owns
  every object and ACLs are ignored.

On by default but tunable:

- **Versioning** — protects against accidental overwrite/deletion.

Optional and off by default:

- **Lifecycle rules** — a single unified list handling transitions, expiration,
  noncurrent-version transitions/expiration, and multipart cleanup.
- **Access logging** — deliver server access logs to a target bucket.
- **Cross-region replication** — hooks for one or more destination buckets.
- **Glue database + crawler** and **Athena workgroup** — created only when
  explicitly enabled, so plain storage buckets stay free of analytics resources.

## Usage

```hcl
module "bucket" {
  source = "../storage"

  project     = "acme"
  environment = "production"
  name        = "app-assets"

  lifecycle_rules = [{
    id                                 = "cleanup"
    noncurrent_version_expiration_days = 30
  }]

  tags = { ManagedBy = "terraform" }
}
```

- [`examples/simple`](./examples/simple) — a secure bucket with lifecycle tiering.
- [`examples/data-lake`](./examples/data-lake) — the optional Glue + Athena stack.

## Analytics stack

Enabling analytics is incremental:

| Variable | Creates |
|----------|---------|
| `enable_glue_database` | `aws_glue_catalog_database` |
| `enable_glue_crawler` (+ `glue_crawler_role_arn`) | `aws_glue_crawler` scanning the bucket |
| `enable_athena_workgroup` | `aws_athena_workgroup` writing encrypted results back to the bucket |

The crawler requires a caller-supplied IAM role (read access to the bucket +
Glue catalog write) — build it with the [`iam`](../iam) module. Query results
are encrypted with the same key as the bucket.

## Notes

- **Replication** requires `versioning_enabled = true` (the default) and a
  caller-supplied `replication_role_arn`. When the destination is KMS-encrypted,
  set `destination_kms_key_arn` and the module enables SSE-KMS object selection.
- For a dedicated audit-log target bucket (e.g. for ALB logs that require
  `AES256`), create a separate bucket with `encryption_type = "AES256"` and point
  `logging_target_bucket` at it. Because buckets in this module use
  `BucketOwnerEnforced` (ACLs disabled), the **target** bucket must grant S3 log
  delivery via its bucket policy (principal `logging.s3.amazonaws.com`), not via
  a log-delivery ACL.
- The always-on bucket policy denies both plain HTTP (`aws:SecureTransport`) and
  TLS versions below 1.2 (`s3:TlsVersion`).

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docs will populate inputs/outputs here on pre-commit -->
<!-- END_TF_DOCS -->
