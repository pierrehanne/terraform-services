// A standalone Application Load Balancer: the load balancer itself, its security
// group, an HTTPS listener (with an HTTP->HTTPS redirect) and an optional WAFv2
// Web ACL. It does NOT own certificates (pass certificate_arn from the dns
// module), target groups or per-app listener rules — consumers such as the
// ecs-fargate module create those and attach them to the exported
// https_listener_arn.

locals {
  name_prefix = "${var.project}-${var.name}"

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
    },
    var.tags
  )

  deletion_protection = var.enable_deletion_protection != null ? var.enable_deletion_protection : var.environment == "production"
}

//---------------------------------------------------------------------
// Security group
//---------------------------------------------------------------------

resource "aws_security_group" "this" {
  name                   = "${local.name_prefix}-alb-sg"
  description            = "Security group for the ${local.name_prefix} ALB"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(
    { Name = "${local.name_prefix}-alb-sg" },
    local.common_tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ingress_https" {
  count = length(var.ingress_cidr_blocks) > 0 ? 1 : 0

  description       = "Allow HTTPS from allowed CIDRs"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.ingress_cidr_blocks
  security_group_id = aws_security_group.this.id
}

resource "aws_security_group_rule" "ingress_http_redirect" {
  count = length(var.ingress_cidr_blocks) > 0 ? 1 : 0

  description       = "Allow HTTP from allowed CIDRs (redirected to HTTPS)"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.ingress_cidr_blocks
  security_group_id = aws_security_group.this.id
}

resource "aws_security_group_rule" "egress" {
  description       = "Allow the ALB to reach targets in the VPC"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this.id
}

//---------------------------------------------------------------------
// Load balancer
//---------------------------------------------------------------------

resource "aws_lb" "this" {
  name               = substr("${local.name_prefix}-alb", 0, 32)
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.this.id]
  subnets            = var.subnet_ids

  idle_timeout               = var.idle_timeout
  drop_invalid_header_fields = true
  enable_deletion_protection = local.deletion_protection

  dynamic "access_logs" {
    for_each = var.access_logs_bucket != null ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = var.access_logs_prefix
      enabled = true
    }
  }

  tags = local.common_tags
}

//---------------------------------------------------------------------
// Listeners
//---------------------------------------------------------------------

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  # Default action for unmatched requests. Consumers attach forwarding rules to
  # this listener via aws_lb_listener_rule.
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not found"
      status_code  = "404"
    }
  }

  tags = local.common_tags
}

resource "aws_lb_listener_certificate" "additional" {
  for_each = toset(var.additional_certificate_arns)

  listener_arn    = aws_lb_listener.https.arn
  certificate_arn = each.value
}

# Redirect all plain HTTP to HTTPS.
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = local.common_tags
}
