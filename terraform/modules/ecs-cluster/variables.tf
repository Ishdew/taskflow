variable "name_prefix" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_security_group_id" {
  description = "ALB security group — hosts accept traffic from here on port 8080."
  type        = string
}

variable "instance_profile_name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "root_volume_size_gb" {
  description = "Root EBS volume per ECS host. 30 GB is the free tier allowance."
  type        = number
  default     = 30
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 2
}

variable "desired_capacity" {
  type    = number
  default = 1
}

variable "project_name" {
  description = "Tag Ansible uses to find these hosts."
  type        = string
  default     = "taskflow"
}

variable "tags" {
  type    = map(string)
  default = {}
}
