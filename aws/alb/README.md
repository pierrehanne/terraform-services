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
<!-- terraform-docs will populate inputs/outputs here on pre-commit -->
<!-- END_TF_DOCS -->
