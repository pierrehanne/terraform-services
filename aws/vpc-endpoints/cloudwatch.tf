locals {
  cloudwatch_services = var.enable_cloudwatch_endpoints ? toset([
    "logs",       # CloudWatch Logs (e.g. awslogs driver, log groups)
    "monitoring", # CloudWatch Metrics
  ]) : []
}

resource "aws_security_group" "cloudwatch" {
  count = var.enable_cloudwatch_endpoints ? 1 : 0

  name                   = "${var.project}-cloudwatch-endpoint-sg"
  description            = "Security group for CloudWatch interface endpoints"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(
    { Name = "${var.project}-cloudwatch-endpoint-sg" },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "cloudwatch_ingress" {
  count = var.enable_cloudwatch_endpoints ? 1 : 0

  description       = "Allow HTTPS inbound from VPC"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.cloudwatch[0].id
}

resource "aws_security_group_rule" "cloudwatch_egress" {
  count = var.enable_cloudwatch_endpoints ? 1 : 0

  description       = "Allow HTTPS outbound to VPC"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.cloudwatch[0].id
}

resource "aws_vpc_endpoint" "cloudwatch" {
  for_each = local.cloudwatch_services

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.cloudwatch[0].id]

  policy = each.key == "logs" ? data.aws_iam_policy_document.cloudwatch_logs_endpoint[0].json : null

  tags = merge(
    { Name = "${var.project}-endpoint-${each.key == "logs" ? "cloudwatch-logs" : "cloudwatch-monitoring"}" },
    var.tags
  )
}

data "aws_iam_policy_document" "cloudwatch_logs_endpoint" {
  count = var.enable_cloudwatch_endpoints ? 1 : 0

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
      values   = [var.vpc_id]
    }
  }
}
