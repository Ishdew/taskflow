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
