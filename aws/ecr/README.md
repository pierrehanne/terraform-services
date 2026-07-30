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
| [aws_ecr_lifecycle_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_lifecycle_policy) | resource |
| [aws_ecr_repository.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_ecr_repository_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_encryption_type"></a> [encryption\_type](#input\_encryption\_type) | Encryption for images at rest: "KMS" (creates a dedicated CMK unless kms\_key\_arn is set) or "AES256" (S3-managed). | `string` | `"KMS"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., production, staging, development) | `string` | n/a | yes |
| <a name="input_force_delete"></a> [force\_delete](#input\_force\_delete) | Whether to delete the repository (and all images) even if it still contains images. Keep false in production. | `bool` | `false` | no |
| <a name="input_image_tag_mutability"></a> [image\_tag\_mutability](#input\_image\_tag\_mutability) | Whether image tags can be overwritten. IMMUTABLE (default) prevents tag reuse — recommended for reproducible deployments. | `string` | `"IMMUTABLE"` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of an existing KMS key to encrypt images. Only used when encryption\_type = "KMS". When null, the module creates a dedicated key. | `string` | `null` | no |
| <a name="input_kms_rotation_period_in_days"></a> [kms\_rotation\_period\_in\_days](#input\_kms\_rotation\_period\_in\_days) | Rotation period for the dedicated KMS key (only when the module creates one). | `number` | `90` | no |
| <a name="input_lifecycle_policy_json"></a> [lifecycle\_policy\_json](#input\_lifecycle\_policy\_json) | Fully custom ECR lifecycle policy (JSON). When set, it replaces the generated policy entirely. | `string` | `null` | no |
| <a name="input_max_tagged_image_count"></a> [max\_tagged\_image\_count](#input\_max\_tagged\_image\_count) | Number of most-recent tagged images to retain. Older tagged images beyond this count are expired. | `number` | `20` | no |
| <a name="input_name"></a> [name](#input\_name) | Repository name (appended to the project to form the repository, e.g. "<project>/<name>") | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | Project name used for naming and organizing resources | `string` | n/a | yes |
| <a name="input_repository_policy_json"></a> [repository\_policy\_json](#input\_repository\_policy\_json) | Fully custom repository (resource) policy (JSON). When null (default), no repository policy is attached. | `string` | `null` | no |
| <a name="input_scan_on_push"></a> [scan\_on\_push](#input\_scan\_on\_push) | Whether to scan images for vulnerabilities on push. | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags applied to all resources created by this module | `map(string)` | `{}` | no |
| <a name="input_untagged_image_expiry_days"></a> [untagged\_image\_expiry\_days](#input\_untagged\_image\_expiry\_days) | Number of days after which untagged images are expired. | `number` | `7` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN of the KMS key used to encrypt images (null when using AES256 or an externally supplied key) |
| <a name="output_registry_id"></a> [registry\_id](#output\_registry\_id) | Registry ID (AWS account ID) where the repository lives |
| <a name="output_repository_arn"></a> [repository\_arn](#output\_repository\_arn) | ARN of the ECR repository |
| <a name="output_repository_name"></a> [repository\_name](#output\_repository\_name) | Name of the ECR repository |
| <a name="output_repository_url"></a> [repository\_url](#output\_repository\_url) | URL of the repository (use as the image push/pull target, e.g. in docker build/push and ECS task definitions) |
<!-- END_TF_DOCS -->
