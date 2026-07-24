resource "aws_security_group" "kms" {
  count = var.enable_kms_endpoint ? 1 : 0

  name                   = "${var.project}-kms-endpoint-sg"
  description            = "Security group for KMS interface endpoint"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(
    { Name = "${var.project}-kms-endpoint-sg" },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "kms_ingress" {
  count = var.enable_kms_endpoint ? 1 : 0

  description       = "Allow HTTPS inbound from VPC"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = project.kms[0].id
}

resource "aws_security_group_rule" "kms_egress" {
  count = var.enable_kms_endpoint ? 1 : 0

  description       = "Allow HTTPS outbound to VPC"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = project.kms[0].id
}

resource "aws_vpc_endpoint" "kms" {
  count = var.enable_kms_endpoint ? 1 : 0

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.kms"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [project.kms[0].id]

  tags = merge(
    { Name = "${var.project}-endpoint-kms" },
    var.tags
  )
}
