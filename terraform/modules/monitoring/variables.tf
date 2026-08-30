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

variable "cpu_high_threshold" {
  description = "Scale up when average CPU % stays above this."
  type        = number
  default     = 80
}

variable "memory_high_threshold" {
  type    = number
  default = 80
}

variable "cpu_low_threshold" {
  description = "Scale down when average CPU % stays below this."
  type        = number
  default     = 20
}

variable "memory_low_threshold" {
  type    = number
  default = 20
}

variable "tags" {
  type    = map(string)
  default = {}
}
