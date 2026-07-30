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
| [aws_appautoscaling_policy.cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.memory](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_ecs_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.execution_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.execution_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lb_listener_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_security_group.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.service_egress_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.service_ingress_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.service_ingress_peers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_iam_policy_document.assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.execution_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_listener_arn"></a> [alb\_listener\_arn](#input\_alb\_listener\_arn) | ARN of an existing HTTPS listener (from the alb module's https\_listener\_arn) to attach per-service target groups and listener rules to. Required when any service sets alb.enabled = true; leave null for services with no load balancer. | `string` | `null` | no |
| <a name="input_alb_security_group_id"></a> [alb\_security\_group\_id](#input\_alb\_security\_group\_id) | Security group ID of the ALB (from the alb module's alb\_security\_group\_id). Services that attach to the ALB allow ingress from this security group. Required when alb\_listener\_arn is set. | `string` | `null` | no |
| <a name="input_capacity_provider_strategy"></a> [capacity\_provider\_strategy](#input\_capacity\_provider\_strategy) | Default cluster capacity provider strategy. Each entry weights FARGATE vs FARGATE\_SPOT. Defaults to 100% on-demand FARGATE for predictable production behaviour. | <pre>list(object({<br/>    capacity_provider = string<br/>    weight            = number<br/>    base              = optional(number)<br/>  }))</pre> | <pre>[<br/>  {<br/>    "base": 1,<br/>    "capacity_provider": "FARGATE",<br/>    "weight": 1<br/>  }<br/>]</pre> | no |
| <a name="input_enable_container_insights"></a> [enable\_container\_insights](#input\_enable\_container\_insights) | Whether to enable CloudWatch Container Insights on the cluster for observability. | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., production, staging, development) | `string` | n/a | yes |
| <a name="input_log_kms_key_arn"></a> [log\_kms\_key\_arn](#input\_log\_kms\_key\_arn) | Optional KMS key ARN to encrypt the CloudWatch Log Groups. When null, logs use default CloudWatch encryption. | `string` | `null` | no |
| <a name="input_log_retention_in_days"></a> [log\_retention\_in\_days](#input\_log\_retention\_in\_days) | Retention in days for the per-service CloudWatch Log Groups. | `number` | `30` | no |
| <a name="input_name"></a> [name](#input\_name) | Cluster name, used to build the cluster and per-service identifiers | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private subnet IDs the ECS tasks run in (from the network module's private\_subnet\_ids) | `list(string)` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | Project name used for naming and organizing resources | `string` | n/a | yes |
| <a name="input_services"></a> [services](#input\_services) | Map of ECS Fargate services to create, keyed by service name. | <pre>map(object({<br/>    # Container<br/>    image   = string<br/>    cpu     = optional(number, 256)<br/>    memory  = optional(number, 512)<br/>    command = optional(list(string))<br/>    port    = optional(number) # container port; required if the service is behind the ALB<br/><br/>    # Container hardening. readonly_root_filesystem defaults on; set a non-root<br/>    # user (e.g. "1000") where the image supports it.<br/>    readonly_root_filesystem = optional(bool, true)<br/>    user                     = optional(string)<br/><br/>    environment = optional(map(string), {})<br/><br/>    # Secrets injected as env vars. Map of ENV_VAR_NAME => Secrets Manager /<br/>    # SSM Parameter ARN. The execution role is granted read + KMS decrypt on these.<br/>    secrets = optional(map(string), {})<br/><br/>    # Desired running tasks (ignored when autoscaling manages the count).<br/>    desired_count = optional(number, 1)<br/><br/>    # Enable ECS Exec (SSM shell into tasks). Off by default; turn on only for<br/>    # debugging and grant the task role SSM messages permissions.<br/>    enable_execute_command = optional(bool, false)<br/><br/>    # Task role permissions (application permissions). Least-privilege statements.<br/>    task_policy_statements = optional(list(object({<br/>      sid       = optional(string)<br/>      effect    = optional(string, "Allow")<br/>      actions   = list(string)<br/>      resources = list(string)<br/>    })), [])<br/><br/>    # KMS keys the execution role may decrypt for secrets (in addition to any<br/>    # inferred from the secret ARNs). Explicit ARNs only.<br/>    secret_kms_key_arns = optional(list(string), [])<br/><br/>    # Autoscaling (target tracking on CPU/memory)<br/>    autoscaling = optional(object({<br/>      min_capacity       = number<br/>      max_capacity       = number<br/>      cpu_target         = optional(number, 70)<br/>      memory_target      = optional(number)<br/>      scale_in_cooldown  = optional(number, 300)<br/>      scale_out_cooldown = optional(number, 60)<br/>    }))<br/><br/>    # ALB attachment. Set authenticate_cognito to put a Cognito login in front<br/>    # of the service (wire the cognito module's outputs into it).<br/>    alb = optional(object({<br/>      enabled              = bool<br/>      path_patterns        = optional(list(string), ["/*"])<br/>      priority             = number<br/>      health_check_path    = optional(string, "/")<br/>      health_check_matcher = optional(string, "200")<br/>      authenticate_cognito = optional(object({<br/>        user_pool_arn       = string<br/>        user_pool_client_id = string<br/>        user_pool_domain    = string<br/>        scope               = optional(string, "openid email profile")<br/>        session_timeout     = optional(number, 3600)<br/>      }))<br/>    }))<br/><br/>    # Allow the service's tasks to receive traffic from these security groups<br/>    # directly (e.g. another service), on the container port.<br/>    ingress_security_group_ids = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags applied to all resources created by this module | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC the services run in | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ARN of the ECS cluster |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | ID of the ECS cluster |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the ECS cluster |
| <a name="output_execution_role_arns"></a> [execution\_role\_arns](#output\_execution\_role\_arns) | Map of service key to execution IAM role ARN |
| <a name="output_log_group_names"></a> [log\_group\_names](#output\_log\_group\_names) | Map of service key to CloudWatch Log Group name |
| <a name="output_service_names"></a> [service\_names](#output\_service\_names) | Map of service key to ECS service name |
| <a name="output_service_security_group_ids"></a> [service\_security\_group\_ids](#output\_service\_security\_group\_ids) | Map of service key to its task security group ID (use to allow service-to-service traffic) |
| <a name="output_target_group_arns"></a> [target\_group\_arns](#output\_target\_group\_arns) | Map of service key to the ALB target group ARN created for it (empty when no service attaches to the ALB) |
| <a name="output_task_definition_arns"></a> [task\_definition\_arns](#output\_task\_definition\_arns) | Map of service key to task definition ARN |
| <a name="output_task_role_arns"></a> [task\_role\_arns](#output\_task\_role\_arns) | Map of service key to task IAM role ARN |
<!-- END_TF_DOCS -->
