locals {
  common_tags = merge(var.tags, {
    Module = "rds"
  })
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-db"
  description = "Postgres for TaskFlow"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Postgres from app hosts"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    description = "Managed service egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-db-sg"
  })
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db"
  subnet_ids = var.private_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-db-subnets"
  })
}

resource "aws_db_instance" "this" {
  identifier = "${var.name_prefix}-postgres"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage_gb
  storage_type      = "gp3"
  db_name           = var.db_name
  username          = var.db_username
  password          = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]

  multi_az            = false
  publicly_accessible = false
  storage_encrypted   = true

  backup_retention_period = var.backup_retention_days
  skip_final_snapshot     = var.skip_final_snapshot
  deletion_protection     = var.deletion_protection

  # Snapshots are useless during an incident if you cannot tell which project they came from.
  copy_tags_to_snapshot = true

  # Picked up automatically within the maintenance window; a Postgres patch release should never
  # need a Terraform change.
  auto_minor_version_upgrade = true

  # Postgres logs go to CloudWatch so slow queries and connection errors are visible next to the
  # application logs, instead of only inside the instance.
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # 7 days of Performance Insights is inside the free allowance and is the fastest way to answer
  # "which query is saturating the database" during the pool-exhaustion incident in the runbook.
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  apply_immediately = true

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-postgres"
  })
}

resource "aws_secretsmanager_secret" "db" {
  name = "${var.name_prefix}/db"

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-db-secret"
  })
}

# ECS reads username/password from here — never plain env vars for credentials.
resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    engine   = "postgres"
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.db_name
  })
}
