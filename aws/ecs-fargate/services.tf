//---------------------------------------------------------------------
// Task definitions (one per service). Container definitions are built with
// jsonencode() over a structured object — never hand-written JSON.
//---------------------------------------------------------------------

resource "aws_ecs_task_definition" "this" {
  for_each = var.services

  family                   = "${local.name_prefix}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.execution[each.key].arn
  task_role_arn            = aws_iam_role.task[each.key].arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    merge(
      {
        name                   = each.key
        image                  = each.value.image
        essential              = true
        readonlyRootFilesystem = each.value.readonly_root_filesystem
      },
      each.value.command != null ? { command = each.value.command } : {},
      each.value.user != null ? { user = each.value.user } : {},
      {

        portMappings = each.value.port == null ? [] : [
          {
            containerPort = each.value.port
            protocol      = "tcp"
          }
        ]

        environment = [
          for k, v in each.value.environment : { name = k, value = v }
        ]

        secrets = [
          for k, v in each.value.secrets : { name = k, valueFrom = v }
        ]

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.this[each.key].name
            "awslogs-region"        = data.aws_region.current.region
            "awslogs-stream-prefix" = each.key
          }
        }
      }
    )
  ])

  tags = local.common_tags
}

//---------------------------------------------------------------------
// Services
//---------------------------------------------------------------------

resource "aws_ecs_service" "this" {
  for_each = var.services

  name            = each.key
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this[each.key].arn
  desired_count   = each.value.desired_count

  enable_execute_command = each.value.enable_execute_command

  # Tag running tasks/ENIs for cost allocation and traceability.
  enable_ecs_managed_tags = true
  propagate_tags          = "TASK_DEFINITION"

  # Roll back automatically if a deployment fails to stabilise.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.service[each.key].id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = contains(keys(local.alb_services), each.key) ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.this[each.key].arn
      container_name   = each.key
      container_port   = each.value.port
    }
  }

  # When autoscaling manages desired_count, ignore drift so Terraform doesn't
  # fight the scaler.
  lifecycle {
    ignore_changes = [desired_count]
  }

  # The ALB listener rule must exist before the service registers targets.
  depends_on = [aws_lb_listener_rule.this]

  tags = local.common_tags
}
