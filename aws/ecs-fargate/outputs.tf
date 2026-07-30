output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.this.id
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

output "service_names" {
  description = "Map of service key to ECS service name"
  value       = { for k, s in aws_ecs_service.this : k => s.name }
}

output "task_definition_arns" {
  description = "Map of service key to task definition ARN"
  value       = { for k, t in aws_ecs_task_definition.this : k => t.arn }
}

output "service_security_group_ids" {
  description = "Map of service key to its task security group ID (use to allow service-to-service traffic)"
  value       = { for k, sg in aws_security_group.service : k => sg.id }
}

output "task_role_arns" {
  description = "Map of service key to task IAM role ARN"
  value       = { for k, r in aws_iam_role.task : k => r.arn }
}

output "execution_role_arns" {
  description = "Map of service key to execution IAM role ARN"
  value       = { for k, r in aws_iam_role.execution : k => r.arn }
}

output "log_group_names" {
  description = "Map of service key to CloudWatch Log Group name"
  value       = { for k, lg in aws_cloudwatch_log_group.this : k => lg.name }
}

//---------------------------------------------------------------------
// ALB attachment (the ALB itself is owned by the alb module)
//---------------------------------------------------------------------

output "target_group_arns" {
  description = "Map of service key to the ALB target group ARN created for it (empty when no service attaches to the ALB)"
  value       = { for k, tg in aws_lb_target_group.this : k => tg.arn }
}
