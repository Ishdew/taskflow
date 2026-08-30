variable "name_prefix" {
  type = string
}

variable "cluster_id" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "capacity_provider_name" {
  type = string
}

variable "service_name" {
  type = string
}

variable "container_image" {
  type = string
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "task_cpu" {
  type    = number
  default = 256
}

variable "task_memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "task_execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "log_group_name" {
  type = string
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type    = number
  default = 5432
}

variable "db_name" {
  type = string
}

variable "db_secret_arn" {
  type = string
}

variable "app_environment" {
  type    = string
  default = "prod"
}

variable "aws_region" {
  type = string
}

variable "stop_timeout_seconds" {
  description = "Must match spring.lifecycle timeout + a little headroom."
  type        = number
  default     = 30
}

variable "enable_horizontal_scaling" {
  description = "Target-tracking autoscaling on desired task count."
  type        = bool
  default     = true
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
  description = "Keep average CPU near this % by adding/removing tasks."
  type        = number
  default     = 60
}

variable "tags" {
  type    = map(string)
  default = {}
}
