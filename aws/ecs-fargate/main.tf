data "aws_region" "current" {}

locals {
  name_prefix = "${var.project}-${var.name}"

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
    },
    var.tags
  )

  # Services that attach to the (externally-provided) ALB listener.
  alb_services = {
    for k, s in var.services : k => s
    if var.alb_listener_arn != null && s.alb != null && try(s.alb.enabled, false)
  }

  # Services with autoscaling configured.
  autoscaled_services = {
    for k, s in var.services : k => s
    if s.autoscaling != null
  }
}

//---------------------------------------------------------------------
// Cluster
//---------------------------------------------------------------------

resource "aws_ecs_cluster" "this" {
  name = local.name_prefix

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  # Catch a service that opts into the ALB without an external listener wired in
  # — otherwise it would silently run with no load balancer attachment.
  lifecycle {
    precondition {
      condition = var.alb_listener_arn != null || alltrue([
        for k, s in var.services : s.alb == null || !try(s.alb.enabled, false)
      ])
      error_message = "A service sets alb.enabled = true but alb_listener_arn is null. Pass the alb module's https_listener_arn (and alb_security_group_id) or remove the per-service alb block."
    }
  }

  tags = local.common_tags
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  dynamic "default_capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy
    content {
      capacity_provider = default_capacity_provider_strategy.value.capacity_provider
      weight            = default_capacity_provider_strategy.value.weight
      base              = default_capacity_provider_strategy.value.base
    }
  }
}
