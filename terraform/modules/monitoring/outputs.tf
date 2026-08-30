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

output "cpu_high_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.ecs_cpu_high.arn
}

output "memory_high_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.ecs_memory_high.arn
}

output "cpu_low_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.ecs_cpu_low.arn
}

output "memory_low_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.ecs_memory_low.arn
}
