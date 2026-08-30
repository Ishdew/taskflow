output "ecs_instance_role_arn" {
  value = aws_iam_role.ecs_instance.arn
}

output "ecs_instance_role_name" {
  value = aws_iam_role.ecs_instance.name
}

output "ecs_instance_profile_name" {
  value = aws_iam_instance_profile.ecs_instance.name
}

output "ecs_instance_profile_arn" {
  value = aws_iam_instance_profile.ecs_instance.arn
}

output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_execution_role_name" {
  value = aws_iam_role.ecs_task_execution.name
}

output "ecs_task_role_arn" {
  value = aws_iam_role.ecs_task.arn
}

output "ecs_task_role_name" {
  value = aws_iam_role.ecs_task.name
}
