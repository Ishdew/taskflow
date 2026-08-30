locals {
  name_prefix  = "${var.project_name}-${var.environment}"
  cluster_name = "${local.name_prefix}-cluster"
  service_name = "${local.name_prefix}-service"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  container_image = "${module.ecr.repository_url}:${var.app_image_tag}"
}

module "network" {
  source = "../../modules/network"

  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  tags        = local.common_tags
}

module "ecr" {
  source = "../../modules/ecr"

  repository_name = var.ecr_repository_name
  max_image_count = var.ecr_max_image_count
  tags            = local.common_tags
}

module "alb" {
  source = "../../modules/alb"

  name_prefix                = local.name_prefix
  vpc_id                     = module.network.vpc_id
  public_subnet_ids          = module.network.public_subnet_ids
  target_port                = var.app_port
  health_check_path          = var.health_check_path
  enable_deletion_protection = var.alb_deletion_protection
  tags                       = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  name_prefix           = local.name_prefix
  cluster_name          = local.cluster_name
  vpc_id                = module.network.vpc_id
  private_subnet_ids    = module.network.private_subnet_ids
  alb_security_group_id = module.alb.alb_security_group_id
  instance_profile_name = module.iam.ecs_instance_profile_name
  instance_type         = var.ecs_instance_type
  min_size              = var.ecs_min_size
  max_size              = var.ecs_max_size
  desired_capacity      = var.ecs_desired_capacity
  project_name          = var.project_name
  tags                  = local.common_tags
}

module "rds" {
  source = "../../modules/rds"

  name_prefix                = local.name_prefix
  vpc_id                     = module.network.vpc_id
  private_subnet_ids         = module.network.private_subnet_ids
  allowed_security_group_ids = [module.ecs_cluster.ecs_host_security_group_id]
  db_name                    = var.db_name
  db_username                = var.db_username
  instance_class             = var.db_instance_class
  allocated_storage_gb       = var.db_allocated_storage_gb
  engine_version             = var.db_engine_version
  backup_retention_days      = var.db_backup_retention_days
  skip_final_snapshot        = var.db_skip_final_snapshot
  deletion_protection        = var.db_deletion_protection
  tags                       = local.common_tags
}

# Let the task execution role read the DB secret (kept here to avoid a module dependency loop).
resource "aws_iam_role_policy" "ecs_task_execution_db_secret" {
  name = "${local.name_prefix}-ecs-task-execution-db-secret"
  role = module.iam.ecs_task_execution_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [module.rds.secret_arn]
    }]
  })
}

module "monitoring" {
  source = "../../modules/monitoring"

  name_prefix        = local.name_prefix
  cluster_name       = local.cluster_name
  service_name       = local.service_name
  log_retention_days = var.log_retention_days
  cpu_threshold      = var.alarm_cpu_threshold
  memory_threshold   = var.alarm_memory_threshold
  tags               = local.common_tags
}

module "ecs_service" {
  source = "../../modules/ecs-service"

  name_prefix             = local.name_prefix
  cluster_id              = module.ecs_cluster.cluster_id
  cluster_name            = module.ecs_cluster.cluster_name
  capacity_provider_name  = module.ecs_cluster.capacity_provider_name
  service_name            = local.service_name
  container_image         = local.container_image
  container_port          = var.app_port
  task_cpu                = var.task_cpu
  task_memory             = var.task_memory
  desired_count           = var.ecs_service_desired_count
  task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn           = module.iam.ecs_task_role_arn
  target_group_arn        = module.alb.target_group_arn
  log_group_name          = module.monitoring.log_group_name
  db_host                 = module.rds.db_endpoint
  db_port                 = module.rds.db_port
  db_name                 = module.rds.db_name
  db_secret_arn           = module.rds.secret_arn
  app_environment         = var.environment
  aws_region              = var.aws_region
  tags                    = local.common_tags
}
