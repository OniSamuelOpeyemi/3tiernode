locals {
  prefix = "${var.project_name}-${var.environment}"
}

# ─── SNS Topic for Alarms ─────────────────────────────────────────────────────
resource "aws_sns_topic" "alarms" {
  name = "${local.prefix}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ─── CloudWatch Alarms: ECS Web ───────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "web_cpu_high" {
  alarm_name          = "${local.prefix}-web-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Web service CPU utilization > 80%"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.web_service_name
  }
}

resource "aws_cloudwatch_metric_alarm" "web_5xx" {
  alarm_name          = "${local.prefix}-web-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Web ALB 5xx errors > 10 in 1 min"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  dimensions          = { LoadBalancer = var.web_alb_arn }
  treat_missing_data  = "notBreaching"
}

# ─── CloudWatch Alarms: ECS API ───────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "api_cpu_high" {
  alarm_name          = "${local.prefix}-api-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "API service CPU utilization > 80%"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.api_service_name
  }
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${local.prefix}-api-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "API ALB 5xx errors > 10 in 1 min"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  dimensions          = { LoadBalancer = var.api_alb_arn }
  treat_missing_data  = "notBreaching"
}

# ─── CloudWatch Alarms: Database ──────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "db_cpu_high" {
  alarm_name          = "${local.prefix}-db-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Aurora CPU > 80%"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  dimensions          = { DBClusterIdentifier = var.db_cluster_id }
}

resource "aws_cloudwatch_metric_alarm" "db_connections_high" {
  alarm_name          = "${local.prefix}-db-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "Aurora connection count > 100"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  dimensions          = { DBClusterIdentifier = var.db_cluster_id }
}

# CloudWatch Dashboard 
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.prefix}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title    = "ECS Web - CPU & Memory"
          region   = "us-east-1"
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          metrics = [
            ["AWS/ECS", "CPUUtilization",    "ClusterName", var.ecs_cluster_name, "ServiceName", var.web_service_name],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.web_service_name]
          ]
        }
        x      = 0
        y      = 0
        width  = 12
        height = 6
      },
      {
        type = "metric"
        properties = {
          title  = "ECS API - CPU & Memory"
          region  = "us-east-1"
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          metrics = [
            ["AWS/ECS", "CPUUtilization",    "ClusterName", var.ecs_cluster_name, "ServiceName", var.api_service_name],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.api_service_name]
          ]
        }
        x      = 12
        y      = 0
        width  = 12
        height = 6
      },
      {
        type = "metric"
        properties = {
          title  = "ALB Request Count & Latency"
          region  = "us-east-1"
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount",  "LoadBalancer", var.web_alb_arn],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.web_alb_arn, { stat = "p99" }],
            ["AWS/ApplicationELB", "RequestCount",  "LoadBalancer", var.api_alb_arn],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.api_alb_arn, { stat = "p99" }]
          ]
        }
        x      = 0
        y      = 6
        width  = 12
        height = 6
      },
      {
        type = "metric"
        properties = {
          title  = "Aurora - CPU, Connections, Latency"
          region  = "us-east-1"
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          metrics = [
            ["AWS/RDS", "CPUUtilization",     "DBClusterIdentifier", var.db_cluster_id],
            ["AWS/RDS", "DatabaseConnections","DBClusterIdentifier", var.db_cluster_id],
            ["AWS/RDS", "CommitLatency",      "DBClusterIdentifier", var.db_cluster_id],
            ["AWS/RDS", "SelectLatency",      "DBClusterIdentifier", var.db_cluster_id]
          ]
        }
        x      = 12
        y      = 6
        width  = 12
        height = 6
      },
      {
        type = "metric"
        properties = {
          title  = "HTTP Error Rates (4xx / 5xx)"
          region  = "us-east-1"
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.web_alb_arn],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.web_alb_arn],
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.api_alb_arn],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.api_alb_arn]
          ]
        }
        x      = 0
        y      = 12
        width  = 24
        height = 6
      }
    ]
  })
}

# Container Insights log group 
resource "aws_cloudwatch_log_group" "ecs_insights" {
  name              = "/aws/ecs/containerinsights/${var.ecs_cluster_name}/performance"
  retention_in_days = 14
}
