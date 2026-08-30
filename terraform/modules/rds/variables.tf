variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups that may connect to Postgres (usually the ECS host group)."
  type        = list(string)
}

variable "db_name" {
  type    = string
  default = "taskflow"
}

variable "db_username" {
  type    = string
  default = "taskflow"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage_gb" {
  type    = number
  default = 20
}

variable "engine_version" {
  type    = string
  default = "16.4"
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "skip_final_snapshot" {
  description = "Set true when you plan to terraform destroy (assignment teardown)."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
