variable "aws_region" {
  description = "Region where the state bucket and lock table live."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Short name used in resource names."
  type        = string
  default     = "taskflow"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name. Include your AWS account id so nobody else has taken it."
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table Terraform uses to lock state during apply."
  type        = string
  default     = "taskflow-terraform-locks"
}
