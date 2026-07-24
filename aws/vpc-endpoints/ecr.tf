locals {
  ecr_services = var.enable_ecr_endpoints ? toset([
    "ecr.api",
    "ecr.dkr",
  ]) : []
}


resource "aws_security_group" "ecr" {
  count = var.enable_ecr_endpoints ? 1 : 0

  name                   = "${var.project}-ecr-endpoint-sg"
  description            = "Security group for ECR interface endpoints"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(
    { Name = "${var.project}-ecr-endpoint-sg" },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ecr_ingress" {
  count = var.enable_ecr_endpoints ? 1 : 0

  description       = "Allow HTTPS inbound from VPC"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.ecr[0].id
}

resource "aws_security_group_rule" "ecr_egress" {
  count = var.enable_ecr_endpoints ? 1 : 0

  description       = "Allow HTTPS outbound to VPC"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.ecr[0].id
}

resource "aws_vpc_endpoint" "ecr" {
  for_each = local.ecr_services

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.ecr[0].id]

  tags = merge(
    { Name = "${var.project}-endpoint-${replace(each.key, ".", "-")}" },
    var.tags
  )
}
