locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

module "network" {
  source = "../../modules/network"

  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  tags        = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

module "ecr" {
  source = "../../modules/ecr"

  repository_name = var.ecr_repository_name
  max_image_count = var.ecr_max_image_count
  tags            = local.common_tags
}
