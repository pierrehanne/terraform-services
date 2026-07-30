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
| [aws_acm_certificate.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_route53_record.alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alias_records"></a> [alias\_records](#input\_alias\_records) | Map of record name => alias target. Creates A-record aliases in the zone pointing at AWS resources such as an ALB. Key is the record FQDN; value carries the target DNS name and hosted zone ID (e.g. an ALB's dns\_name and zone\_id). | <pre>map(object({<br/>    target_dns_name        = string<br/>    target_zone_id         = string<br/>    evaluate_target_health = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| <a name="input_certificate_domain_name"></a> [certificate\_domain\_name](#input\_certificate\_domain\_name) | Primary domain name for the ACM certificate (e.g. "*.prod.example.com"). Must fall within the hosted zone so DNS validation records can be created. | `string` | n/a | yes |
| <a name="input_existing_zone_id"></a> [existing\_zone\_id](#input\_existing\_zone\_id) | ID of an existing Route53 hosted zone to reuse. When null (default) the module creates and manages the zone named zone\_name. When set, the module reuses that zone and creates no zone resource. | `string` | `null` | no |
| <a name="input_subject_alternative_names"></a> [subject\_alternative\_names](#input\_subject\_alternative\_names) | Additional domains (SANs) to include on the certificate. Each must fall within the hosted zone. | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags applied to all resources created by this module | `map(string)` | `{}` | no |
| <a name="input_validation_record_ttl"></a> [validation\_record\_ttl](#input\_validation\_record\_ttl) | TTL in seconds for the ACM DNS validation records. | `number` | `60` | no |
| <a name="input_wait_for_validation"></a> [wait\_for\_validation](#input\_wait\_for\_validation) | Whether to block (via aws\_acm\_certificate\_validation) until the certificate is issued. Set false to create the validation records without waiting — useful when the zone's name servers are not yet delegated. | `bool` | `true` | no |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | Fully-qualified name of the Route53 hosted zone (e.g. "prod.example.com"). Used to create the zone when existing\_zone\_id is null, and to look it up otherwise. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_certificate_arn"></a> [certificate\_arn](#output\_certificate\_arn) | ARN of the ACM certificate. When wait\_for\_validation is true this is only returned after issuance completes, so it is safe to pass straight to an ALB listener. |
| <a name="output_certificate_domain_name"></a> [certificate\_domain\_name](#output\_certificate\_domain\_name) | Primary domain name on the issued certificate |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | ID of the Route53 hosted zone (created or reused) |
| <a name="output_zone_name"></a> [zone\_name](#output\_zone\_name) | Name of the Route53 hosted zone |
| <a name="output_zone_name_servers"></a> [zone\_name\_servers](#output\_zone\_name\_servers) | Name servers for the created zone (empty when reusing an existing zone). Delegate these from the parent domain. |
<!-- END_TF_DOCS -->
