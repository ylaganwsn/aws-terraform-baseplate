resource "aws_sns_topic" "sns_alarm_topic" {
  name        = "${var.project_name}-${var.environment}-Alarms"
  display_name = "${var.project_name}-${var.environment}-Alarms"
}

resource "aws_sns_topic_subscription" "email_subscription1" {
  topic_arn = aws_sns_topic.sns_alarm_topic.arn
  protocol  = "email"
  endpoint  = var.email_add1
}

resource "aws_sns_topic_subscription" "https_subscription" {
  topic_arn = aws_sns_topic.sns_alarm_topic.arn
  protocol  = "https"
  endpoint  = var.https_endpnt
}

resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "${var.project_name}-${var.environment}-CPU-Alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "${var.project_name}-${var.environment} Server CPU Usage High"
  alarm_actions       = [aws_sns_topic.sns_alarm_topic.arn]

  dimensions = {
    AutoScalingGroupName = "${var.ec2_as_group_name}"
  }
}

resource "aws_cloudwatch_metric_alarm" "disk_alarm" {
  alarm_name          = "${var.project_name}-${var.environment}-Disk-Alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "${var.project_name}-${var.environment} Server Disk Usage High"
  alarm_actions       = [aws_sns_topic.sns_alarm_topic.arn]

  dimensions = {
    AutoScalingGroupName = "${var.ec2_as_group_name}"
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_alarm" {
  alarm_name          = "${var.project_name}-${var.environment}-Memory-Alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "${var.project_name}-${var.environment} Server Memory Usage"
  alarm_actions       = [aws_sns_topic.sns_alarm_topic.arn]

  dimensions = {
    AutoScalingGroupName = "${var.ec2_as_group_name}"
  }
}