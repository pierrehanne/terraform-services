//---------------------------------------------------------------------
// ALB attachment (optional, per service that opts in).
//
// This module does NOT own the ALB. The caller creates it with the `alb`
// module and passes alb_listener_arn (the HTTPS listener) and
// alb_security_group_id. Here we create one target group + listener rule per
// attached service and, optionally, a Cognito authentication action in front of
// the forward.
//---------------------------------------------------------------------

resource "aws_lb_target_group" "this" {
  for_each = local.alb_services

  name        = substr("${local.name_prefix}-${each.key}", 0, 32)
  port        = each.value.port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # required for Fargate awsvpc networking

  health_check {
    path    = try(each.value.alb.health_check_path, "/")
    matcher = try(each.value.alb.health_check_matcher, "200")
  }

  tags = local.common_tags
}

resource "aws_lb_listener_rule" "this" {
  for_each = local.alb_services

  listener_arn = var.alb_listener_arn
  priority     = each.value.alb.priority

  # Optional Cognito authentication in front of the forward. Ordered so the
  # authenticate action runs first, then the request is forwarded on success.
  dynamic "action" {
    for_each = each.value.alb.authenticate_cognito != null ? [each.value.alb.authenticate_cognito] : []
    content {
      order = 1
      type  = "authenticate-cognito"

      authenticate_cognito {
        user_pool_arn       = action.value.user_pool_arn
        user_pool_client_id = action.value.user_pool_client_id
        user_pool_domain    = action.value.user_pool_domain
        scope               = action.value.scope
        session_timeout     = action.value.session_timeout
      }
    }
  }

  action {
    order            = each.value.alb.authenticate_cognito != null ? 2 : 1
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.key].arn
  }

  condition {
    path_pattern {
      values = try(each.value.alb.path_patterns, ["/*"])
    }
  }
}
