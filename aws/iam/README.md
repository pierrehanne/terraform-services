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
<!-- terraform-docs will populate inputs/outputs here on pre-commit -->
<!-- END_TF_DOCS -->
