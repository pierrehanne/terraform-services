# ==============================================================================
# Security Group for Interface Endpoints
# ==============================================================================

resource "aws_security_group" "endpoints" {
  count = length(local.interface_services) > 0 ? 1 : 0

  name        = "${local.name_prefix}-endpoints"
  description = "Shared security group for interface VPC endpoints"

  vpc_id                 = aws_vpc.this.id
  revoke_rules_on_delete = true

  tags = merge(
    {
      Name = "${local.name_prefix}-endpoints"
      Tier = "endpoint"
    },
    local.common_tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# Endpoint Security Group - Ingress
# ==============================================================================

resource "aws_security_group_rule" "endpoints_ingress" {
  count = length(local.interface_services) > 0 ? 1 : 0

  description = "Allow HTTPS inbound from the VPC"

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.this.cidr_block]
  security_group_id = aws_security_group.endpoints[0].id
}

# ==============================================================================
# Endpoint Security Group - Egress
# ==============================================================================

resource "aws_security_group_rule" "endpoints_egress" {
  count = length(local.interface_services) > 0 ? 1 : 0

  description = "Allow HTTPS outbound to AWS services"

  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.this.cidr_block]
  security_group_id = aws_security_group.endpoints[0].id
}

# ==============================================================================
# Interface VPC Endpoints
# ==============================================================================

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_services

  vpc_id = aws_vpc.this.id

  service_name = "com.amazonaws.${data.aws_region.current.region}.${each.key}"

  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  # In a single-AZ dev environment this creates one ENI.
  # In production, use multiple AZs for HA.
  subnet_ids = local.private_subnet_ids

  security_group_ids = [
    aws_security_group.endpoints[0].id
  ]

  # Restrict CloudWatch Logs endpoint access to this VPC.
  policy = each.key == "logs" ? (
    data.aws_iam_policy_document.logs_endpoint[0].json
  ) : null

  tags = merge(
    {
      Name = "${local.name_prefix}-endpoint-${replace(each.key, ".", "-")}"
    },
    local.common_tags
  )
}

# ==============================================================================
# CloudWatch Logs Endpoint Policy
# ==============================================================================

data "aws_iam_policy_document" "logs_endpoint" {
  count = contains(local.interface_services, "logs") ? 1 : 0

  statement {
    sid    = "AllowLogsFromVPC"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
    ]

    resources = (
      var.cloudwatch_log_group_arns != null &&
      length(var.cloudwatch_log_group_arns) > 0
      ? var.cloudwatch_log_group_arns
      : ["*"]
    )

    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpc"
      values   = [aws_vpc.this.id]
    }
  }
}
