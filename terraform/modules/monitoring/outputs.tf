output "log_group_name" {
  value = aws_cloudwatch_log_group.ecs.name
}

output "log_group_arn" {
  value = aws_cloudwatch_log_group.ecs.arn
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  value = aws_sns_topic.alerts.name
}

output "cpu_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.ecs_cpu_high.arn
}

output "memory_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.ecs_memory_high.arn
}
