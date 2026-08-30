variable "name_prefix" {
  description = "Prefix for resource names, e.g. taskflow-prod."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR for the whole VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "tags" {
  description = "Extra tags to merge onto every resource."
  type        = map(string)
  default     = {}
}
