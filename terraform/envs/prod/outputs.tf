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

output "ecs_instance_profile_name" {
  value = module.iam.ecs_instance_profile_name
}

output "ecs_task_execution_role_arn" {
  value = module.iam.ecs_task_execution_role_arn
}

output "ecs_task_role_arn" {
  value = module.iam.ecs_task_role_arn
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "ecr_repository_name" {
  value = module.ecr.repository_name
}
