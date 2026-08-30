variable "name_prefix" {
  description = "Prefix for role and policy names."
  type        = string
}

variable "db_secret_arn" {
  description = "RDS secret in Secrets Manager. Leave empty until Phase 3b wires RDS."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
