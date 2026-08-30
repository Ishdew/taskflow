output "repository_name" {
  value = aws_ecr_repository.this.name
}

output "repository_arn" {
  value = aws_ecr_repository.this.arn
}

output "repository_url" {
  value = aws_ecr_repository.this.repository_url
}

output "registry_id" {
  value = aws_ecr_repository.this.registry_id
}
