//---------------------------------------------------------------------
// Application Auto Scaling (optional, per service). Target-tracking on CPU
// and, optionally, memory utilisation.
//---------------------------------------------------------------------

resource "aws_appautoscaling_target" "this" {
  for_each = local.autoscaled_services

  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = each.value.autoscaling.min_capacity
  max_capacity       = each.value.autoscaling.max_capacity
}

resource "aws_appautoscaling_policy" "cpu" {
  for_each = local.autoscaled_services

  name               = "${local.name_prefix}-${each.key}-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this[each.key].service_namespace
  resource_id        = aws_appautoscaling_target.this[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.this[each.key].scalable_dimension

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = each.value.autoscaling.cpu_target
    scale_in_cooldown  = each.value.autoscaling.scale_in_cooldown
    scale_out_cooldown = each.value.autoscaling.scale_out_cooldown
  }
}

resource "aws_appautoscaling_policy" "memory" {
  for_each = {
    for k, s in local.autoscaled_services : k => s
    if s.autoscaling.memory_target != null
  }

  name               = "${local.name_prefix}-${each.key}-memory"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this[each.key].service_namespace
  resource_id        = aws_appautoscaling_target.this[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.this[each.key].scalable_dimension

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = each.value.autoscaling.memory_target
    scale_in_cooldown  = each.value.autoscaling.scale_in_cooldown
    scale_out_cooldown = each.value.autoscaling.scale_out_cooldown
  }
}
