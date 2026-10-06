locals {
  common_tags = merge(var.tags, {
    Module = "monitoring"
  })
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "/ecs/${var.name_prefix}"
  })
}

# Alarms publish here. Phase 4 Lambda is subscribed in the vertical-scaler module.
resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-alerts"
  })
}

# One pane of glass for an on-call engineer: latency and throughput at the edge, utilisation of the
# running tasks (the same metrics the vertical scaler reacts to), and how many tasks are actually up.
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name_prefix}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Request latency (seconds)"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "Average", label = "avg" }],
            ["...", { stat = "p95", label = "p95" }],
            ["...", { stat = "p99", label = "p99" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Requests and HTTP errors"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          stat   = "Sum"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { label = "requests" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", var.alb_arn_suffix, { label = "2xx" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.alb_arn_suffix, { label = "4xx" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { label = "5xx" }],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { label = "elb 5xx" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ECS service utilisation (drives vertical scaling)"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          stat   = "Average"
          yAxis  = { left = { min = 0, max = 100 } }
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name, "ServiceName", var.service_name, { label = "cpu %" }],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.cluster_name, "ServiceName", var.service_name, { label = "memory %" }],
          ]
          annotations = {
            horizontal = [
              { label = "scale up", value = var.cpu_high_threshold },
              { label = "scale down", value = var.cpu_low_threshold },
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Healthy tasks and cluster capacity"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", var.target_group_arn_suffix, "LoadBalancer", var.alb_arn_suffix, { label = "healthy targets" }],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "TargetGroup", var.target_group_arn_suffix, "LoadBalancer", var.alb_arn_suffix, { label = "unhealthy targets" }],
            ["AWS/ECS", "CPUReservation", "ClusterName", var.cluster_name, { label = "cluster cpu reserved %" }],
            ["AWS/ECS", "MemoryReservation", "ClusterName", var.cluster_name, { label = "cluster memory reserved %" }],
          ]
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title  = "Recent application errors"
          region = var.aws_region
          view   = "table"
          query  = "SOURCE '${aws_cloudwatch_log_group.ecs.name}' | fields @timestamp, log.level, message, error.type | filter log.level in ['ERROR', 'WARN'] | sort @timestamp desc | limit 50"
        }
      },
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.name_prefix}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_high_threshold
  alarm_description   = "CPU is high — vertical scaler should step up"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${var.name_prefix}-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.memory_high_threshold
  alarm_description   = "Memory is high — vertical scaler should step up"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

# Quiet periods. The Lambda only acts on ALARM state, so OK transitions are ignored.
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_low" {
  alarm_name          = "${var.name_prefix}-ecs-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_low_threshold
  alarm_description   = "CPU is low — vertical scaler should step down"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_low" {
  alarm_name          = "${var.name_prefix}-ecs-memory-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 5
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.memory_low_threshold
  alarm_description   = "Memory is low — vertical scaler should step down"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}
