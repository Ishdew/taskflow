output "db_instance_id" {
  value = aws_db_instance.this.id
}

output "db_endpoint" {
  value = aws_db_instance.this.address
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = var.db_name
}

output "db_username" {
  value = var.db_username
}

output "db_security_group_id" {
  value = aws_security_group.db.id
}

output "secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}

output "secret_name" {
  value = aws_secretsmanager_secret.db.name
}
