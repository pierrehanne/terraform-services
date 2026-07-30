//---------------------------------------------------------------------
// Interface VPC endpoints (PrivateLink)
//
// Keeping AWS API traffic on PrivateLink means private workloads never reach
// ECR, CloudWatch Logs, etc. over a NAT gateway or the public Internet — the
// cheapest and most secure posture. A baseline set is ALWAYS created for a
// private VPC and cannot be disabled; the rest are opt-in.
//---------------------------------------------------------------------

data "aws_region" "current" {}

locals {
  # Interface/gateway endpoints only make sense when there are private subnets
  # to host their ENIs (interface) or private route tables to target (gateway).
  create_endpoints = length(var.private_subnet_cidrs) > 0

  # Always-on: ECR (image pulls) and CloudWatch Logs (log delivery). Combined
  # with the S3 gateway endpoint (see endpoints-gateway.tf, also always-on),
  # this covers the full "ECS task pulls an image and ships logs" path without
  # any NAT gateway.
  baseline_interface_services = [
    "ecr.api",
    "ecr.dkr",
    "logs",
  ]

  # Opt-in extras, toggled per service group.
  optional_interface_services = concat(
    var.enable_bedrock_endpoints ? [
      "bedrock",
      "bedrock-agent",
      "bedrock-agent-runtime",
      "bedrock-agentcore",
      "bedrock-runtime",
    ] : [],
    var.enable_cloudwatch_monitoring_endpoint ? ["monitoring"] : [],
    var.enable_kms_endpoint ? ["kms"] : [],
    var.enable_secretsmanager_endpoint ? ["secretsmanager"] : [],
    var.enable_transcribe_endpoint ? ["transcribe"] : [],
  )

  interface_services = local.create_endpoints ? toset(concat(
    local.baseline_interface_services,
    local.optional_interface_services,
  )) : toset([])
}

// All interface endpoints share one security group: every endpoint ENI needs
// exactly the same rule (HTTPS from within the VPC), so a single group avoids
// six identical copies.
resource "aws_security_group" "endpoints" {
  count = local.create_endpoints ? 1 : 0

  name                   = "${local.name_prefix}-endpoints"
  description            = "Shared security group for interface VPC endpoints"
  vpc_id                 = aws_vpc.this.id
  revoke_rules_on_delete = true

  tags = merge(
    { Name = "${local.name_prefix}-endpoints" },
    local.common_tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "endpoints_ingress" {
  count = local.create_endpoints ? 1 : 0

  description       = "Allow HTTPS inbound from the VPC"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.this.cidr_block]
  security_group_id = aws_security_group.endpoints[0].id
}

resource "aws_security_group_rule" "endpoints_egress" {
  count = local.create_endpoints ? 1 : 0

  description       = "Allow HTTPS outbound to the VPC"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.this.cidr_block]
  security_group_id = aws_security_group.endpoints[0].id
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_services

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for k, s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.endpoints[0].id]

  # Scope the Logs endpoint to this VPC (and optionally to specific log groups).
  policy = each.key == "logs" ? data.aws_iam_policy_document.logs_endpoint[0].json : null

  tags = merge(
    { Name = "${local.name_prefix}-endpoint-${replace(each.key, ".", "-")}" },
    local.common_tags
  )
}

data "aws_iam_policy_document" "logs_endpoint" {
  count = local.create_endpoints ? 1 : 0

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

    resources = var.cloudwatch_log_group_arns != null && length(var.cloudwatch_log_group_arns) > 0 ? var.cloudwatch_log_group_arns : ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpc"
      values   = [aws_vpc.this.id]
    }
  }
}
