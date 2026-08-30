output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "availability_zones" {
  value = module.network.availability_zones
}

output "alb_dns_name" {
  description = "Hit http://<this>/health after deploy."
  value       = module.alb.alb_dns_name
}

output "alb_url" {
  value = "http://${module.alb.alb_dns_name}"
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "ecs_cluster_name" {
  value = module.ecs_cluster.cluster_name
}

output "ecs_service_name" {
  value = module.ecs_service.service_name
}

output "ecs_task_definition_arn" {
  value = module.ecs_service.task_definition_arn
}

output "rds_endpoint" {
  value = module.rds.db_endpoint
}

output "db_secret_arn" {
  sensitive = true
  value     = module.rds.secret_arn
}

output "cloudwatch_log_group" {
  value = module.monitoring.log_group_name
}

output "sns_alerts_topic_arn" {
  value = module.monitoring.sns_topic_arn
}

output "vertical_scaler_function_name" {
  value = module.vertical_scaler.lambda_function_name
}

output "vertical_scaler_size_ladder" {
  value = module.vertical_scaler.size_ladder
}

output "horizontal_scaling_enabled" {
  value = module.ecs_service.horizontal_scaling_enabled
}

output "ecs_instance_profile_name" {
  value = module.iam.ecs_instance_profile_name
}

output "ecs_task_execution_role_arn" {
  value = module.iam.ecs_task_execution_role_arn
}

output "ecs_task_role_arn" {
  value = module.iam.ecs_task_role_arn
}
