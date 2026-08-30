variable "name_prefix" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "service_name" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "cpu_threshold" {
  description = "Alarm when average CPU % goes above this."
  type        = number
  default     = 80
}

variable "memory_threshold" {
  type    = number
  default = 80
}

variable "tags" {
  type    = map(string)
  default = {}
}
