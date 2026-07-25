resource "aws_security_group" "aurora" {
  name                   = "${var.project}-${var.name}-sg"
  description            = "Security group for Aurora PostgreSQL cluster ${var.name}"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(
    { Name = "${var.project}-${var.name}-sg" },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ingress_security_groups" {
  count = length(var.allowed_security_group_ids)

  description              = "Allow PostgreSQL from security group"
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_group_ids[count.index]
  security_group_id        = aws_security_group.aurora.id
}

resource "aws_security_group_rule" "ingress_cidr_blocks" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0

  description       = "Allow PostgreSQL from CIDR blocks"
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.aurora.id
}

resource "aws_security_group_rule" "egress" {
  description       = "Allow all outbound"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.aurora.id
}
