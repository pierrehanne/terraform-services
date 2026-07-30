# DNS

Route53 hosted zone and ACM certificate management for a domain. The module
creates (or reuses) a hosted zone, issues a DNS-validated ACM certificate, and
optionally publishes alias records pointing at AWS resources such as an ALB.

It owns DNS and certificates only. Load balancers live in the `alb` module and
authentication in the `cognito` module — this module hands the `alb` module a
`certificate_arn` and receives an ALB `dns_name`/`zone_id` back for its alias
records.

## Design principles

- **Create-or-reuse zone** — set `existing_zone_id` to reuse a delegated zone;
  leave it null to have the module create and manage the zone named `zone_name`.
- **DNS-validated certificates** — validation records are written into the same
  zone automatically. `wait_for_validation` (default `true`) blocks until the
  certificate is issued so downstream listeners never reference a pending cert.
- **Safe cert replacement** — `create_before_destroy` on the certificate avoids
  removing an in-use certificate out from under a listener.
- **Alias helper** — `alias_records` publishes A-record aliases (e.g. an app
  hostname to an ALB) without a separate module.

## Usage

```hcl
module "dns" {
  source = "../dns"

  zone_name               = "prod.example.com"
  certificate_domain_name = "*.prod.example.com"

  alias_records = {
    "app.prod.example.com" = {
      target_dns_name = module.alb.alb_dns_name
      target_zone_id  = module.alb.alb_zone_id
    }
  }

  tags = { ManagedBy = "terraform" }
}
```

- [`examples/new-zone`](./examples/new-zone) — create a zone and wildcard cert.
- [`examples/existing-zone`](./examples/existing-zone) — reuse a zone and add an
  ALB alias record.

## Notes

- When the module creates the zone, delegate `zone_name_servers` from the parent
  domain so validation can complete. Until delegation is in place, set
  `wait_for_validation = false` to create the records without blocking.
- `certificate_domain_name` and every `subject_alternative_names` entry must
  fall within the hosted zone, otherwise the validation records cannot resolve.
- The exported `certificate_arn` is the validated ARN when
  `wait_for_validation = true`, so it is safe to feed straight into the `alb`
  module's `certificate_arn`.

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docs will populate inputs/outputs here on pre-commit -->
<!-- END_TF_DOCS -->
