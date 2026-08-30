variable "repository_name" {
  description = "ECR repo name, usually taskflow."
  type        = string
}

variable "image_tag_mutability" {
  description = "IMMUTABLE is safer for prod; MUTABLE is easier while iterating locally."
  type        = string
  default     = "IMMUTABLE"
}

variable "scan_on_push" {
  description = "Run a vulnerability scan when CI pushes a new image."
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "How many tagged images to keep before the lifecycle rule expires old ones."
  type        = number
  default     = 20
}

variable "tags" {
  type    = map(string)
  default = {}
}
