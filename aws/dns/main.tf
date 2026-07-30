// Create-or-reuse a Route53 hosted zone, issue an ACM certificate validated
// against that zone, and (optionally) publish alias records pointing at AWS
// resources such as an ALB. This module owns DNS and certificates only — it
// creates no load balancers or auth resources.

locals {
  create_zone = var.existing_zone_id == null

  # The zone the certificate validation records and aliases are written into,
  # whether freshly created here or supplied by the caller.
  zone_id = local.create_zone ? aws_route53_zone.this[0].zone_id : var.existing_zone_id
}

//---------------------------------------------------------------------
// Hosted zone (created only when no existing zone is supplied)
//---------------------------------------------------------------------

resource "aws_route53_zone" "this" {
  count = local.create_zone ? 1 : 0

  name = var.zone_name

  tags = merge(
    { Name = var.zone_name },
    var.tags
  )
}

//---------------------------------------------------------------------
// Certificate
//---------------------------------------------------------------------

resource "aws_acm_certificate" "this" {
  domain_name               = var.certificate_domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"

  tags = merge(
    { Name = var.certificate_domain_name },
    var.tags
  )

  # ACM recommends replacing before destroying so an in-use certificate is not
  # removed out from under a listener.
  lifecycle {
    create_before_destroy = true
  }
}

//---------------------------------------------------------------------
// DNS validation records
//---------------------------------------------------------------------

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = var.validation_record_ttl
  type            = each.value.type
  zone_id         = local.zone_id
}

resource "aws_acm_certificate_validation" "this" {
  count = var.wait_for_validation ? 1 : 0

  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}

//---------------------------------------------------------------------
// Alias records (e.g. app.prod.example.com -> ALB)
//---------------------------------------------------------------------

resource "aws_route53_record" "alias" {
  for_each = var.alias_records

  zone_id = local.zone_id
  name    = each.key
  type    = "A"

  alias {
    name                   = each.value.target_dns_name
    zone_id                = each.value.target_zone_id
    evaluate_target_health = each.value.evaluate_target_health
  }
}
