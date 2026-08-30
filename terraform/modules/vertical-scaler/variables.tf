variable "name_prefix" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "service_name" {
  type = string
}

variable "sns_topic_arn" {
  description = "Alarms publish here; we subscribe the Lambda to it."
  type        = string
}

variable "task_execution_role_arn" {
  description = "Needed so RegisterTaskDefinition can PassRole."
  type        = string
}

variable "task_role_arn" {
  type = string
}

variable "size_ladder" {
  description = "CPU/memory steps the Lambda walks through."
  type = list(object({
    cpu    = number
    memory = number
  }))
  default = [
    { cpu = 256, memory = 512 },
    { cpu = 512, memory = 1024 },
    { cpu = 1024, memory = 2048 },
  ]
}

variable "lambda_source_dir" {
  description = "Folder that contains handler.py"
  type        = string
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "tags" {
  type    = map(string)
  default = {}
}
