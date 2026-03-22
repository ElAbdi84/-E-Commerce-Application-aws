# terraform/cloudwatch.tf
# ============================================================================
# CLOUDWATCH MONITORING - PARTIE 8
# ============================================================================

# ==================== LOG GROUPS ====================

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/aws/eks/${var.cluster_name}/backend"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-backend-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/aws/eks/${var.cluster_name}/frontend"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-frontend-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/aws/eks/${var.cluster_name}/worker"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-worker-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/eks/${var.cluster_name}/application"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-application-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ==================== IAM POLICY FOR FLUENTBIT ====================

data "aws_iam_policy_document" "fluentbit_cloudwatch" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "fluentbit_cloudwatch" {
  name        = "${var.project_name}-fluentbit-cloudwatch"
  description = "Policy for FluentBit to send logs to CloudWatch"
  policy      = data.aws_iam_policy_document.fluentbit_cloudwatch.json

  tags = {
    Name        = "${var.project_name}-fluentbit-policy"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ==================== CLOUDWATCH ALARMS ====================

# Alarm: Backend CPU High
resource "aws_cloudwatch_metric_alarm" "backend_cpu_high" {
  alarm_name          = "${var.project_name}-backend-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "pod_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Backend CPU utilization is too high"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    Namespace   = "default"
    PodName     = "backend"
  }

  tags = {
    Name        = "${var.project_name}-backend-cpu-alarm"
    Environment = var.environment
  }
}

# Alarm: Worker Memory High
resource "aws_cloudwatch_metric_alarm" "worker_memory_high" {
  alarm_name          = "${var.project_name}-worker-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "pod_memory_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Worker memory utilization is too high"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    Namespace   = "default"
    PodName     = "worker"
  }

  tags = {
    Name        = "${var.project_name}-worker-memory-alarm"
    Environment = var.environment
  }
}

# Alarm: ALB 5xx Errors
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project_name}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Too many 5xx errors from ALB"
  treat_missing_data  = "notBreaching"

  tags = {
    Name        = "${var.project_name}-alb-5xx-alarm"
    Environment = var.environment
  }
}

# ==================== OUTPUTS ====================

output "cloudwatch_log_groups" {
  description = "CloudWatch Log Groups"
  value = {
    backend     = aws_cloudwatch_log_group.backend.name
    frontend    = aws_cloudwatch_log_group.frontend.name
    worker      = aws_cloudwatch_log_group.worker.name
    application = aws_cloudwatch_log_group.application.name
  }
}

output "cloudwatch_alarms" {
  description = "CloudWatch Alarms"
  value = {
    backend_cpu    = aws_cloudwatch_metric_alarm.backend_cpu_high.alarm_name
    worker_memory  = aws_cloudwatch_metric_alarm.worker_memory_high.alarm_name
    alb_5xx        = aws_cloudwatch_metric_alarm.alb_5xx_errors.alarm_name
  }
}
