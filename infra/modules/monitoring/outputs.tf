output "sns_topic_arn" {
  description = "SNS Topic ARN for CloudWatch Alarms"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  description = "CloudWatch Dashboard Name"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}
