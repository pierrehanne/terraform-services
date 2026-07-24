locals {
  bedrock_services = var.enable_bedrock_endpoints ? toset([
    "bedrock",
    "bedrock-agent",
    "bedrock-agent-runtime",
    "bedrock-agentcore",
    "bedrock-runtime",
  ]) : []
}

resource "aws_security_group" "bedrock" {
  count = var.enable_bedrock_endpoints ? 1 : 0

  name                   = "${var.project}-bedrock-endpoint-sg"
  description            = "Security group for Bedrock interface endpoints"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(
    { Name = "${var.project}-bedrock-endpoint-sg" },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "bedrock_ingress" {
  count = var.enable_bedrock_endpoints ? 1 : 0

  description       = "Allow HTTPS inbound from VPC"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.bedrock[0].id
}

resource "aws_security_group_rule" "bedrock_egress" {
  count = var.enable_bedrock_endpoints ? 1 : 0

  description       = "Allow HTTPS outbound to VPC (endpoint ENIs only need to talk back to callers)"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.bedrock[0].id
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.bedrock_services

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.bedrock[0].id]

  tags = merge(
    { Name = "${var.project}-endpoint-${each.key}" },
    var.tags
  )
}
