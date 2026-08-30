variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "target_port" {
  type    = number
  default = 8080
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "enable_deletion_protection" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
