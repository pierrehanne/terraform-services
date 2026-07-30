# ECS Fargate

A reusable ECS Fargate module that runs **many independent services** in one
cluster. Each service has its own image, sizing, IAM roles, secrets, log group,
security group, autoscaling and (optionally) a target group attached to an
externally-provided ALB listener.

## Design principles

- **One cluster, many services.** `services` is a map keyed by service name.
  Each entry is fully independent — different image, CPU/memory, environment,
  secrets, task-role permissions, and scaling — without the module becoming a
  generic god-module.
- **Container definitions are structured**, built with `jsonencode()` over a
  typed object — never hand-written JSON.
- **Least-privilege IAM per service.** Each service gets its own execution role
  (image pull + logs + read of *exactly its* secrets and their KMS keys) and its
  own task role (only the application statements you declare). No shared,
  over-broad roles.
- **Secure networking.** Tasks run in private subnets with `assign_public_ip =
  false`. Ingress is only from the ALB or explicitly allowed peer security
  groups; egress is limited to HTTPS.
- **Safe rollouts.** Deployment circuit breaker with automatic rollback is on;
  `desired_count` drift is ignored so autoscaling isn't fought by Terraform.
- **Observability by default.** Container Insights on; a per-service CloudWatch
  log group (optionally KMS-encrypted).

## ALB scope

This module does **not** own the ALB — the `alb` module does (load balancer,
listeners, security group, WAF). Create the ALB there and pass its
`https_listener_arn` as `alb_listener_arn` and its `alb_security_group_id`. For
each service that sets `alb.enabled = true`, this module then creates one target
group + path-based listener rule attached to that listener, and allows ingress
to the service from the ALB security group. Point a Route53 alias (via the `dns`
module) at the ALB's `alb_dns_name` / `alb_zone_id`.

To put a login in front of a service, set the per-service
`alb.authenticate_cognito` block with the `cognito` module's outputs
(`user_pool_arn`, `user_pool_client_id`, `user_pool_domain`); the listener rule
then runs an `authenticate-cognito` action before forwarding.

## Usage

```hcl
module "ecs" {
  source = "../ecs-fargate"

  project     = "acme"
  environment = "production"
  name        = "web"

  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  services = {
    worker = {
      image  = "${module.ecr.repository_url}:1.0.0"
      cpu    = 512
      memory = 1024
      autoscaling = { min_capacity = 1, max_capacity = 10 }
    }
  }

  tags = { ManagedBy = "terraform" }
}
```

- [`examples/simple`](./examples/simple) — a single worker, no load balancer, CPU autoscaling.
- [`examples/with-alb`](./examples/with-alb) — the full stack: network → dns → cognito → alb → ecs-fargate, two web services routed by path with Cognito auth.

## Composition

- **network** → `vpc_id`, `private_subnet_ids`.
- **dns** → the ACM `certificate_arn` for the `alb` module, and a Route53 alias
  pointing at the ALB.
- **alb** → `alb_listener_arn` (its `https_listener_arn`) and
  `alb_security_group_id`.
- **cognito** → the per-service `alb.authenticate_cognito` block
  (`user_pool_arn`, `user_pool_client_id`, `user_pool_domain`).
- **ecr** → service `image` (`<repository_url>:<tag>`).
- **secrets-manager / aurora-postgresql** → service `secrets` map (ARN values)
  and `secret_kms_key_arns`.

## Notes

- `cpu` must be a valid Fargate value (256, 512, 1024, …); a service behind the
  ALB must set a container `port`. Both are enforced by variable validation.
- A service with `alb.enabled = true` requires `alb_listener_arn` (and its
  companion `alb_security_group_id`) to be set — enforced by a precondition.
- To allow service-to-service traffic, pass one service's
  `service_security_group_ids` output into another's `ingress_security_group_ids`.
- **Secrets on a customer-managed KMS key:** the execution role is granted
  `secretsmanager:GetSecretValue` / `ssm:GetParameters` automatically, but if the
  secret is encrypted with a CMK you must also pass that key in the service's
  `secret_kms_key_arns` — otherwise the task fails at launch with
  `ResourceInitializationError`. Secrets on the default AWS-managed key need
  nothing extra.
- Containers run with a read-only root filesystem by default
  (`readonly_root_filesystem`); set it false per service if the app writes to
  disk, or mount a writable volume. `enable_execute_command` (ECS Exec) is off by
  default.

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docs will populate inputs/outputs here on pre-commit -->
<!-- END_TF_DOCS -->
