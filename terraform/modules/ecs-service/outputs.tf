output "task_definition_arn" {
  value = aws_ecs_task_definition.app.arn
}

output "task_definition_family" {
  value = aws_ecs_task_definition.app.family
}

output "task_definition_revision" {
  value = aws_ecs_task_definition.app.revision
}

output "service_id" {
  value = aws_ecs_service.app.id
}

output "service_name" {
  value = aws_ecs_service.app.name
}

output "horizontal_scaling_enabled" {
  value = var.enable_horizontal_scaling
}
