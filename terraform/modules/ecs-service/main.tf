locals {
  common_tags = merge(var.tags, {
    Module = "ecs-service"
  })

  container_name = "taskflow"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.name_prefix}-app"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name      = local.container_name
    image     = var.container_image
    essential = true

    # hostPort 0 = dynamic. Needed so more than one task can land on the same EC2 host.
    portMappings = [{
      containerPort = var.container_port
      hostPort      = 0
      protocol      = "tcp"
    }]

    # Non-secret config only. Password comes from Secrets Manager below.
    environment = [
      { name = "DB_HOST", value = var.db_host },
      { name = "DB_PORT", value = tostring(var.db_port) },
      { name = "DB_NAME", value = var.db_name },
      { name = "DB_SSL_MODE", value = "require" },
      { name = "APP_ENVIRONMENT", value = var.app_environment },
      { name = "SERVER_PORT", value = tostring(var.container_port) },
      { name = "SHUTDOWN_TIMEOUT", value = "25s" },
      { name = "LOG_LEVEL", value = "INFO" },
      { name = "APP_LOG_LEVEL", value = "INFO" },
    ]

    secrets = [
      {
        name      = "DB_USERNAME"
        valueFrom = "${var.db_secret_arn}:username::"
      },
      {
        name      = "DB_PASSWORD"
        valueFrom = "${var.db_secret_arn}:password::"
      },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = var.log_group_name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -fsS http://127.0.0.1:${var.container_port}/health/liveness || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }

    stopTimeout = var.stop_timeout_seconds
  }])

  tags = local.common_tags
}

resource "aws_ecs_service" "app" {
  name            = var.service_name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider_name
    weight            = 1
    base              = 1
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = local.container_name
    container_port   = var.container_port
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 120

  # Vertical scaler registers new task defs; horizontal autoscaling changes
  # desired_count. Without these, terraform apply would undo both.
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = local.common_tags
}

# Bonus horizontal scaling: more/fewer tasks, same size.
resource "aws_appautoscaling_target" "ecs" {
  count = var.enable_horizontal_scaling ? 1 : 0

  max_capacity       = var.horizontal_max_capacity
  min_capacity       = var.horizontal_min_capacity
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  count = var.enable_horizontal_scaling ? 1 : 0

  name               = "${var.name_prefix}-cpu-target-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.horizontal_cpu_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
