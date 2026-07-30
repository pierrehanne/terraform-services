# ECR

An opinionated Elastic Container Registry module: one repository, secure by
default, ready for applications to push images into.

## Design principles

- **Immutable tags by default.** `image_tag_mutability = "IMMUTABLE"` prevents a
  tag from being overwritten, so a deployed image digest is reproducible.
- **Scanning on by default.** `scan_on_push = true` runs vulnerability scanning
  on every push.
- **Encrypted by default.** Images are encrypted with a dedicated KMS key
  (created via the shared [`kms`](../kms) module) unless you pass your own key
  or opt down to `AES256`.
- **Bounded storage.** A default lifecycle policy expires untagged images after
  7 days and keeps the most recent 20 tagged images — repositories never grow
  unbounded. Both counts are tunable.
- **No repository policy by default.** Access is granted through IAM identity
  policies on the consumers (ECS task roles, CI roles). For the rare case that
  needs a resource-based policy, pass `repository_policy_json`.

## Usage

```hcl
module "ecr" {
  source = "../ecr"

  project     = "acme"
  environment = "production"
  name        = "orders-api"

  tags = { ManagedBy = "terraform" }
}

# module.ecr.repository_url -> <account>.dkr.ecr.<region>.amazonaws.com/acme/orders-api
```

- [`examples/simple`](./examples/simple) — a private repository with all secure defaults.

## Notes

- The generated lifecycle policy expires **untagged** images first (priority 1),
  then caps **tagged** images to `max_tagged_image_count` (priority 10). ECR
  lifecycle rules cannot exempt specific tag prefixes from a count rule, so to
  guarantee an image is never expired, reference it by digest in deployments or
  supply a custom `lifecycle_policy_json`.
- For a completely custom lifecycle policy, pass `lifecycle_policy_json`; it
  replaces the generated document entirely. To attach a resource-based
  repository policy, pass `repository_policy_json`.
- The dedicated KMS key is only created when `encryption_type = "KMS"` and
  `kms_key_arn` is null.

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docs will populate inputs/outputs here on pre-commit -->
<!-- END_TF_DOCS -->
