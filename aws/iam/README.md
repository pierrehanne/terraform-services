# IAM

A lightweight IAM role factory. It creates one role with a trust policy, attaches
existing managed policies, and (optionally) generates a least-privilege
customer-managed policy from structured statements.

## Design principles

- **Structured over stringly-typed.** Permissions are expressed as typed
  `inline_policy_statements` rendered through `aws_iam_policy_document`, not raw
  JSON blobs. This keeps ARNs explicit and lets the module validate them.
- **Least privilege enforced.** `Allow` statements may not use `"*"` as a
  resource — a validation rule rejects it. Use scoped ARNs (or an explicit
  `Deny` if a wildcard is genuinely required).
- **No hardcoded accounts.** The module never bakes in account IDs or ARNs;
  callers pass explicit ARNs.
- **ECS-first defaults.** `trusted_services` defaults to
  `["ecs-tasks.amazonaws.com"]`, the most common workload in this library, so an
  ECS task role needs almost no configuration.
- **Managed + generated policies compose.** Attach AWS-managed policies via
  `managed_policy_arns` and layer a scoped inline policy on top.

## Usage

```hcl
module "task_role" {
  source = "../iam"

  project     = "acme"
  environment = "production"
  name        = "orders-task"

  inline_policy_statements = [{
    sid       = "ReadConfig"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::acme-config/*"]
  }]

  tags = { ManagedBy = "terraform" }
}
```

- [`examples/ecs-task`](./examples/ecs-task) — an ECS task role with scoped S3 + KMS access.
- [`examples/service-role`](./examples/service-role) — a cross-account CI role with an ExternalId condition.

## Notes

- To build an **ECS execution role**, attach the AWS-managed policy and add a
  scoped secrets/KMS statement:

  ```hcl
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
  inline_policy_statements = [{
    sid       = "ReadSecrets"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [module.db.secret_arn]
  }]
  ```

- The `policy_json` escape hatch exists for policies the structured input cannot
  express; prefer `inline_policy_statements` wherever possible.

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
| [aws_iam_policy.custom](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.custom](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., production, staging, development) | `string` | n/a | yes |
| <a name="input_inline_policy_statements"></a> [inline\_policy\_statements](#input\_inline\_policy\_statements) | Least-privilege statements rendered into a single customer-managed policy and<br/>attached to the role. Prefer this over passing raw JSON: it is typed, validated,<br/>and keeps ARNs explicit. Leave empty to attach no custom policy. | <pre>list(object({<br/>    sid       = optional(string)<br/>    effect    = optional(string, "Allow")<br/>    actions   = list(string)<br/>    resources = list(string)<br/>    conditions = optional(list(object({<br/>      test     = string<br/>      variable = string<br/>      values   = list(string)<br/>    })), [])<br/>  }))</pre> | `[]` | no |
| <a name="input_managed_policy_arns"></a> [managed\_policy\_arns](#input\_managed\_policy\_arns) | ARNs of existing (AWS-managed or customer-managed) policies to attach to the role. | `list(string)` | `[]` | no |
| <a name="input_max_session_duration"></a> [max\_session\_duration](#input\_max\_session\_duration) | Maximum session duration (in seconds) for the role, between 3600 and 43200. | `number` | `3600` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the role, used to build the role and policy identifiers | `string` | n/a | yes |
| <a name="input_permissions_boundary_arn"></a> [permissions\_boundary\_arn](#input\_permissions\_boundary\_arn) | Optional ARN of a policy set as the permissions boundary for the role. | `string` | `null` | no |
| <a name="input_policy_json"></a> [policy\_json](#input\_policy\_json) | Escape hatch: a fully pre-rendered IAM policy document (JSON) to attach in addition to inline\_policy\_statements. Use only when the structured input cannot express the policy. | `string` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Project name used for naming and organizing resources | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags applied to all resources created by this module | `map(string)` | `{}` | no |
| <a name="input_trust_conditions"></a> [trust\_conditions](#input\_trust\_conditions) | Optional conditions applied to the AssumeRole statement (e.g. sts:ExternalId, aws:SourceArn). Keyed by condition operator. | <pre>list(object({<br/>    test     = string<br/>    variable = string<br/>    values   = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_trusted_role_arns"></a> [trusted\_role\_arns](#input\_trusted\_role\_arns) | IAM role/user ARNs allowed to assume this role (for cross-account or human/CI access). Prefer explicit ARNs over account roots. | `list(string)` | `[]` | no |
| <a name="input_trusted_services"></a> [trusted\_services](#input\_trusted\_services) | AWS service principals allowed to assume the role (e.g. ["ecs-tasks.amazonaws.com", "lambda.amazonaws.com"]). | `list(string)` | <pre>[<br/>  "ecs-tasks.amazonaws.com"<br/>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_custom_policy_arn"></a> [custom\_policy\_arn](#output\_custom\_policy\_arn) | ARN of the customer-managed policy created from policy\_json (null when not provided) |
| <a name="output_inline_policy_arn"></a> [inline\_policy\_arn](#output\_inline\_policy\_arn) | ARN of the customer-managed policy generated from inline\_policy\_statements (null when none provided) |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of the IAM role (pass to ECS task/execution role inputs, Lambda, etc.) |
| <a name="output_role_id"></a> [role\_id](#output\_role\_id) | Stable, unique ID of the IAM role |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Name of the IAM role |
<!-- END_TF_DOCS -->
