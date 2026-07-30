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

| Name | Source | Version |
|------|--------|---------|
| <a name="module_encryption_kms"></a> [encryption\_kms](#module\_encryption\_kms) | ../kms | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_athena_workgroup.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_workgroup) | resource |
| [aws_glue_catalog_database.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_catalog_database) | resource |
| [aws_glue_crawler.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_crawler) | resource |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_replication_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_replication_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_iam_policy_document.bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_athena_results_prefix"></a> [athena\_results\_prefix](#input\_athena\_results\_prefix) | Key prefix under which Athena query results are stored in this bucket. | `string` | `"athena-results/"` | no |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Explicit, globally-unique bucket name. When null, defaults to "<project>-<name>". Bucket names must be globally unique across all of AWS. | `string` | `null` | no |
| <a name="input_enable_athena_workgroup"></a> [enable\_athena\_workgroup](#input\_enable\_athena\_workgroup) | Whether to create an Athena workgroup with query results written to this bucket (encrypted). | `bool` | `false` | no |
| <a name="input_enable_glue_crawler"></a> [enable\_glue\_crawler](#input\_enable\_glue\_crawler) | Whether to create a Glue Crawler that catalogs this bucket. Requires enable\_glue\_database and glue\_crawler\_role\_arn. | `bool` | `false` | no |
| <a name="input_enable_glue_database"></a> [enable\_glue\_database](#input\_enable\_glue\_database) | Whether to create a Glue Catalog database for this bucket's data. | `bool` | `false` | no |
| <a name="input_encryption_type"></a> [encryption\_type](#input\_encryption\_type) | Server-side encryption: "KMS" (creates a dedicated CMK unless kms\_key\_arn is set) or "AES256" (S3-managed keys). | `string` | `"KMS"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., production, staging, development) | `string` | n/a | yes |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Whether Terraform may delete the bucket even if it still contains objects. Keep false in production. | `bool` | `false` | no |
| <a name="input_glue_crawler_role_arn"></a> [glue\_crawler\_role\_arn](#input\_glue\_crawler\_role\_arn) | ARN of the IAM role the Glue Crawler assumes (needs read access to the bucket and Glue catalog write). Required when enable\_glue\_crawler is true. | `string` | `null` | no |
| <a name="input_glue_crawler_s3_path"></a> [glue\_crawler\_s3\_path](#input\_glue\_crawler\_s3\_path) | S3 path the crawler scans, e.g. "s3://my-bucket/data/". Defaults to the bucket root when null. | `string` | `null` | no |
| <a name="input_glue_crawler_schedule"></a> [glue\_crawler\_schedule](#input\_glue\_crawler\_schedule) | Cron schedule for the crawler (e.g. "cron(0 2 * * ? *)"). When null, the crawler runs on demand only. | `string` | `null` | no |
| <a name="input_glue_database_name"></a> [glue\_database\_name](#input\_glue\_database\_name) | Name of the Glue Catalog database. Defaults to "<project>\_<name>" (hyphens replaced with underscores) when null. | `string` | `null` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of an existing KMS key to encrypt objects. Only used when encryption\_type = "KMS". When null, the module creates a dedicated key. | `string` | `null` | no |
| <a name="input_kms_rotation_period_in_days"></a> [kms\_rotation\_period\_in\_days](#input\_kms\_rotation\_period\_in\_days) | Rotation period for the dedicated KMS key (only when the module creates one). | `number` | `90` | no |
| <a name="input_lifecycle_rules"></a> [lifecycle\_rules](#input\_lifecycle\_rules) | Lifecycle rules. Each rule may filter by prefix, transition current/noncurrent versions to other storage classes, expire them, and abort incomplete multipart uploads. | <pre>list(object({<br/>    id     = string<br/>    prefix = optional(string)<br/><br/>    transitions = optional(list(object({<br/>      days          = number<br/>      storage_class = string<br/>    })), [])<br/><br/>    expiration_days = optional(number)<br/><br/>    noncurrent_version_transitions = optional(list(object({<br/>      days          = number<br/>      storage_class = string<br/>    })), [])<br/><br/>    noncurrent_version_expiration_days = optional(number)<br/><br/>    abort_incomplete_multipart_upload_days = optional(number, 7)<br/>  }))</pre> | `[]` | no |
| <a name="input_logging_target_bucket"></a> [logging\_target\_bucket](#input\_logging\_target\_bucket) | Name of an existing bucket to receive S3 server access logs. When null, access logging is disabled. | `string` | `null` | no |
| <a name="input_logging_target_prefix"></a> [logging\_target\_prefix](#input\_logging\_target\_prefix) | Key prefix for delivered access logs in the target bucket. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Logical bucket name (combined with project to form the bucket name unless bucket\_name is set) | `string` | n/a | yes |
| <a name="input_policy_json"></a> [policy\_json](#input\_policy\_json) | Additional bucket policy statements (JSON) merged with the always-on TLS-only deny. Use for cross-account or service grants. | `string` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Project name used for naming and organizing resources | `string` | n/a | yes |
| <a name="input_replication_role_arn"></a> [replication\_role\_arn](#input\_replication\_role\_arn) | ARN of the IAM role S3 assumes to replicate objects. Required to enable replication; when null, replication is disabled. | `string` | `null` | no |
| <a name="input_replication_rules"></a> [replication\_rules](#input\_replication\_rules) | Replication rules. Each targets a destination bucket ARN, optionally under a prefix, with a storage class and optional destination KMS key. | <pre>list(object({<br/>    id                      = string<br/>    prefix                  = optional(string)<br/>    destination_bucket_arn  = string<br/>    storage_class           = optional(string, "STANDARD")<br/>    destination_kms_key_arn = optional(string)<br/>    priority                = optional(number)<br/>  }))</pre> | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags applied to all resources created by this module | `map(string)` | `{}` | no |
| <a name="input_versioning_enabled"></a> [versioning\_enabled](#input\_versioning\_enabled) | Whether object versioning is enabled. On by default to protect against accidental overwrite/deletion. | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_athena_workgroup_name"></a> [athena\_workgroup\_name](#output\_athena\_workgroup\_name) | Name of the Athena workgroup |
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN of the bucket |
| <a name="output_bucket_domain_name"></a> [bucket\_domain\_name](#output\_bucket\_domain\_name) | Regional domain name of the bucket |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | Name (ID) of the bucket |
| <a name="output_glue_crawler_name"></a> [glue\_crawler\_name](#output\_glue\_crawler\_name) | Name of the Glue Crawler |
| <a name="output_glue_database_name"></a> [glue\_database\_name](#output\_glue\_database\_name) | Name of the Glue Catalog database |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN of the KMS key used to encrypt objects (null when using AES256 or an externally supplied key) |
<!-- END_TF_DOCS -->
