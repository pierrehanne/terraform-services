output "alb_arn" {
  description = "ARN of the ALB"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB (point Route53 alias records at this via the dns module)"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the ALB (for Route53 alias records)"
  value       = aws_lb.this.zone_id
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB (pass to ecs-fargate as alb_security_group_id so services allow ingress from it)"
  value       = aws_security_group.this.id
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener. Consumers (e.g. ecs-fargate) attach their target groups and listener rules to this."
  value       = aws_lb_listener.https.arn
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener (redirects to HTTPS)"
  value       = aws_lb_listener.http_redirect.arn
}

//---------------------------------------------------------------------
// WAF (null when not created)
//---------------------------------------------------------------------

output "waf_web_acl_arn" {
  description = "ARN of the WAFv2 Web ACL attached to the ALB"
  value       = try(aws_wafv2_web_acl.this[0].arn, null)
}

output "waf_web_acl_id" {
  description = "ID of the WAFv2 Web ACL attached to the ALB"
  value       = try(aws_wafv2_web_acl.this[0].id, null)
}
