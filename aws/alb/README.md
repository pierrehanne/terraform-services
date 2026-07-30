# ALB

A standalone Application Load Balancer building block: the load balancer, its
security group, an HTTPS listener (with an HTTP→HTTPS redirect) and an optional
regional WAFv2 Web ACL.

The module is deliberately unopinionated about what runs behind it. It does
**not** own certificates, target groups or per-app listener rules — it consumes
a `certificate_arn` (from the `dns` module) and exports `https_listener_arn`,
`alb_security_group_id`, `alb_dns_name` and `alb_zone_id` so consumers like the
`ecs-fargate` module attach their own target groups and listener rules, and the
`dns` module publishes alias records.

## Design principles

- **Single responsibility** — LB + listeners + SG + WAF. Routing lives with the
  workload that owns the target group; certificates live in `dns`.
- **Secure by default** — HTTPS-only with an HTTP→HTTPS redirect, a modern
  TLS 1.3 policy, `drop_invalid_header_fields`, a 404 default action, deletion
  protection in production, and WAF **on by default** (`enable_waf = true`).
- **Private by default** — `internal = true` and no ingress rule unless
  `ingress_cidr_blocks` is set. Opt in explicitly for internet-facing use.
- **WAF baseline** — AWS managed CommonRuleSet + KnownBadInputs in block mode
  and a per-IP rate limit; append your own managed rule groups, optionally in
  count mode for tuning, via `waf_managed_rule_groups`.

## Usage

```hcl
module "alb" {
  source = "../alb"

  project     = "acme"
  environment = "production"
  name        = "web"

  vpc_id              = module.network.vpc_id
  internal            = false
  subnet_ids          = module.network.public_subnet_ids
  ingress_cidr_blocks = ["0.0.0.0/0"]
  certificate_arn     = module.dns.certificate_arn
  access_logs_bucket  = "acme-alb-logs"

  tags = { ManagedBy = "terraform" }
}

# Attach workloads (e.g. ecs-fargate) to module.alb.https_listener_arn
# and its alb_security_group_id.
```

- [`examples/public-with-waf`](./examples/public-with-waf) — internet-facing ALB
  with WAF.
- [`examples/internal`](./examples/internal) — VPC-internal ALB.

## Notes

- `subnet_ids` must be at least two subnets in different AZs — public for an
  internet-facing ALB, private for an internal one.
- `certificate_arn` is required; issue it with the `dns` module and pass its
  `certificate_arn` output straight through.
- Deletion protection follows `environment == "production"` unless you override
  it with `enable_deletion_protection`.
- To add Cognito authentication, wire the `cognito` module's outputs into the
  consuming module's per-rule `authenticate_cognito` block (e.g. ecs-fargate) —
  the listener created here is the one those rules attach to.

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
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http_redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener_certificate.additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_certificate) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ingress_http_redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ingress_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_wafv2_web_acl.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_logs_bucket"></a> [access\_logs\_bucket](#input\_access\_logs\_bucket) | Optional S3 bucket name for ALB access logs. When null, access logging is disabled (enable it in production). | `string` | `null` | no |
| <a name="input_access_logs_prefix"></a> [access\_logs\_prefix](#input\_access\_logs\_prefix) | Optional object-key prefix for ALB access logs within access\_logs\_bucket. | `string` | `null` | no |
| <a name="input_additional_certificate_arns"></a> [additional\_certificate\_arns](#input\_additional\_certificate\_arns) | Extra ACM certificate ARNs to attach to the HTTPS listener (SNI) beyond the default certificate\_arn. | `list(string)` | `[]` | no |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | ARN of the ACM certificate for the HTTPS listener (from the dns module's certificate\_arn). | `string` | n/a | yes |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | Override deletion protection. When null (default) it is enabled automatically when environment == "production". | `bool` | `null` | no |
| <a name="input_enable_waf"></a> [enable\_waf](#input\_enable\_waf) | Whether to attach a regional WAFv2 Web ACL to the ALB. Blocks common web exploits, known-bad inputs and abusive request rates by default. | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., production, staging, development). Deletion protection is enabled automatically in production. | `string` | n/a | yes |
| <a name="input_idle_timeout"></a> [idle\_timeout](#input\_idle\_timeout) | Idle connection timeout in seconds. | `number` | `60` | no |
| <a name="input_ingress_cidr_blocks"></a> [ingress\_cidr\_blocks](#input\_ingress\_cidr\_blocks) | CIDR blocks allowed to reach the ALB on 443. Empty (default) creates no ingress rule — set explicitly (e.g. the VPC CIDR for an internal ALB, or wider for internet-facing). | `list(string)` | `[]` | no |
| <a name="input_internal"></a> [internal](#input\_internal) | Whether the ALB is internal (no public IP). Recommended default for private workloads; set false only for internet-facing services. | `bool` | `true` | no |
| <a name="input_name"></a> [name](#input\_name) | Load balancer name, used to build the ALB and related identifiers | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | Project name used for naming and organizing resources | `string` | n/a | yes |
| <a name="input_ssl_policy"></a> [ssl\_policy](#input\_ssl\_policy) | TLS security policy for the HTTPS listener. | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs the ALB is placed in. Use public subnets for an internet-facing ALB and private subnets for an internal one — at least two across different AZs. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags applied to all resources created by this module | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC the ALB and its target groups live in | `string` | n/a | yes |
| <a name="input_waf_managed_rule_groups"></a> [waf\_managed\_rule\_groups](#input\_waf\_managed\_rule\_groups) | Additional managed rule groups to append after the baseline, e.g. AWS SQL injection or IP-reputation sets. Set override\_to\_count to run a group in count (observe) mode instead of block. | <pre>list(object({<br/>    name              = string<br/>    vendor_name       = optional(string, "AWS")<br/>    priority          = number<br/>    override_to_count = optional(bool, false)<br/>  }))</pre> | `[]` | no |
| <a name="input_waf_rate_limit"></a> [waf\_rate\_limit](#input\_waf\_rate\_limit) | Per-source-IP request threshold over a 5-minute window, above which the rate-based rule blocks. Only used when enable\_waf is true. | `number` | `2000` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ARN of the ALB |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | DNS name of the ALB (point Route53 alias records at this via the dns module) |
| <a name="output_alb_security_group_id"></a> [alb\_security\_group\_id](#output\_alb\_security\_group\_id) | Security group ID of the ALB (pass to ecs-fargate as alb\_security\_group\_id so services allow ingress from it) |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | Hosted zone ID of the ALB (for Route53 alias records) |
| <a name="output_http_listener_arn"></a> [http\_listener\_arn](#output\_http\_listener\_arn) | ARN of the HTTP listener (redirects to HTTPS) |
| <a name="output_https_listener_arn"></a> [https\_listener\_arn](#output\_https\_listener\_arn) | ARN of the HTTPS listener. Consumers (e.g. ecs-fargate) attach their target groups and listener rules to this. |
| <a name="output_waf_web_acl_arn"></a> [waf\_web\_acl\_arn](#output\_waf\_web\_acl\_arn) | ARN of the WAFv2 Web ACL attached to the ALB |
| <a name="output_waf_web_acl_id"></a> [waf\_web\_acl\_id](#output\_waf\_web\_acl\_id) | ID of the WAFv2 Web ACL attached to the ALB |
<!-- END_TF_DOCS -->
