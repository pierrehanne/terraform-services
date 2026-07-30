output "zone_id" {
  description = "ID of the Route53 hosted zone (created or reused)"
  value       = local.zone_id
}

output "zone_name" {
  description = "Name of the Route53 hosted zone"
  value       = var.zone_name
}

output "zone_name_servers" {
  description = "Name servers for the created zone (empty when reusing an existing zone). Delegate these from the parent domain."
  value       = local.create_zone ? aws_route53_zone.this[0].name_servers : []
}

output "certificate_arn" {
  description = "ARN of the ACM certificate. When wait_for_validation is true this is only returned after issuance completes, so it is safe to pass straight to an ALB listener."
  value       = var.wait_for_validation ? aws_acm_certificate_validation.this[0].certificate_arn : aws_acm_certificate.this.arn
}

output "certificate_domain_name" {
  description = "Primary domain name on the issued certificate"
  value       = aws_acm_certificate.this.domain_name
}
