//---------------------------------------------------------------------
// Per-service task security group.
//
// Ingress is added only from the ALB (when attached) or from explicitly
// allowed peer security groups. Egress is open (443/tcp to anywhere) so tasks
// can pull images and reach AWS APIs; when the VPC has interface endpoints this
// still stays inside the VPC.
//---------------------------------------------------------------------

resource "aws_security_group" "service" {
  for_each = var.services

  name                   = "${local.name_prefix}-${each.key}-sg"
  description            = "Security group for ECS service ${each.key}"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(
    { Name = "${local.name_prefix}-${each.key}-sg" },
    local.common_tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Outbound HTTPS (image pulls, AWS APIs, secrets). Kept to 443 rather than
# all-traffic; widen deliberately per service if an app needs other egress.
resource "aws_security_group_rule" "service_egress_https" {
  for_each = var.services

  description       = "Allow HTTPS outbound"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.service[each.key].id
}

# Ingress from the externally-provided ALB security group on the container port.
resource "aws_security_group_rule" "service_ingress_alb" {
  for_each = local.alb_services

  description              = "Allow traffic from the ALB"
  type                     = "ingress"
  from_port                = each.value.port
  to_port                  = each.value.port
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id
  security_group_id        = aws_security_group.service[each.key].id
}

# Ingress from explicitly allowed peer security groups (service-to-service).
resource "aws_security_group_rule" "service_ingress_peers" {
  # Key on the list index, never the SG ID: peer SG IDs are frequently computed
  # (e.g. another service's SG from this module), and for_each keys must be
  # known at plan time.
  for_each = merge([
    for k, s in var.services : {
      for idx, sg in s.ingress_security_group_ids :
      "${k}:${idx}" => { service = k, source_sg = sg, port = s.port }
    } if s.port != null
  ]...)

  description              = "Allow traffic from peer security group"
  type                     = "ingress"
  from_port                = each.value.port
  to_port                  = each.value.port
  protocol                 = "tcp"
  source_security_group_id = each.value.source_sg
  security_group_id        = aws_security_group.service[each.value.service].id
}
