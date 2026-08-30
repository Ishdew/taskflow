variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "taskflow"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "ecr_repository_name" {
  type    = string
  default = "taskflow"
}

variable "ecr_max_image_count" {
  type    = number
  default = 20
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "app_image_tag" {
  description = "Docker tag pushed to ECR before first deploy (CI uses the git SHA)."
  type        = string
  default     = "latest"
}

variable "alb_deletion_protection" {
  type    = bool
  default = false
}

variable "ecs_instance_type" {
  type    = string
  default = "t3.small"
}

variable "ecs_min_size" {
  type    = number
  default = 1
}

variable "ecs_max_size" {
  type    = number
  default = 2
}

variable "ecs_desired_capacity" {
  type    = number
  default = 1
}

variable "ecs_service_desired_count" {
  type    = number
  default = 1
}

variable "task_cpu" {
  type    = number
  default = 256
}

variable "task_memory" {
  type    = number
  default = 512
}

variable "db_name" {
  type    = string
  default = "taskflow"
}

variable "db_username" {
  type    = string
  default = "taskflow"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_allocated_storage_gb" {
  type    = number
  default = 20
}

variable "db_engine_version" {
  type    = string
  default = "16.15"
}

variable "db_backup_retention_days" {
  type    = number
  default = 1
}

variable "db_skip_final_snapshot" {
  type    = bool
  default = true
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "alarm_cpu_high_threshold" {
  type    = number
  default = 80
}

variable "alarm_memory_high_threshold" {
  type    = number
  default = 80
}

variable "alarm_cpu_low_threshold" {
  type    = number
  default = 20
}

variable "alarm_memory_low_threshold" {
  type    = number
  default = 20
}

variable "enable_horizontal_scaling" {
  type    = bool
  default = true
}

variable "horizontal_min_capacity" {
  type    = number
  default = 1
}

variable "horizontal_max_capacity" {
  type    = number
  default = 2
}

variable "horizontal_cpu_target" {
  type    = number
  default = 60
}
