# ============================================================================
# SQS QUEUES - Traitement Asynchrone
# ============================================================================
# 
# Crée :
#   - Queue SQS principale pour les messages
#   - Dead Letter Queue (DLQ) pour les messages en erreur
#   - IAM Roles pour Backend et Worker
# ============================================================================

# ============================================================================
# DEAD LETTER QUEUE (DLQ)
# ============================================================================
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-dlq"
  message_retention_seconds = 1209600  # 14 jours
  
  tags = {
    Name        = "${var.project_name}-dlq"
    Environment = var.environment
    Purpose     = "Dead Letter Queue for failed messages"
  }
}

# ============================================================================
# MAIN SQS QUEUE
# ============================================================================
resource "aws_sqs_queue" "main" {
  name                       = "${var.project_name}-queue"
  visibility_timeout_seconds = 300  # 5 minutes (temps max traitement message)
  message_retention_seconds  = 345600  # 4 jours
  delay_seconds             = 0
  receive_wait_time_seconds = 20  # Long polling (économise coûts)
  
  # Configuration Dead Letter Queue
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3  # Après 3 tentatives → DLQ
  })
  
  tags = {
    Name        = "${var.project_name}-queue"
    Environment = var.environment
    Purpose     = "Main queue for async processing"
  }
}

# ============================================================================
# IAM POLICY - ENVOYER MESSAGES (Backend)
# ============================================================================
resource "aws_iam_policy" "sqs_send" {
  name        = "${var.project_name}-sqs-send-policy"
  description = "Allow sending messages to SQS queue"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.main.arn
      }
    ]
  })
}

# ============================================================================
# IAM POLICY - CONSOMMER MESSAGES (Worker)
# ============================================================================
resource "aws_iam_policy" "sqs_consume" {
  name        = "${var.project_name}-sqs-consume-policy"
  description = "Allow consuming messages from SQS queue"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = [
          aws_sqs_queue.main.arn,
          aws_sqs_queue.dlq.arn
        ]
      }
    ]
  })
}

# ============================================================================
# IAM ROLE - Backend (Envoyer messages)
# ============================================================================
resource "aws_iam_role" "backend_sqs" {
  name = "${var.project_name}-backend-sqs-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  
  tags = {
    Name = "${var.project_name}-backend-sqs-role"
  }
}

resource "aws_iam_role_policy_attachment" "backend_sqs_send" {
  role       = aws_iam_role.backend_sqs.name
  policy_arn = aws_iam_policy.sqs_send.arn
}

# ============================================================================
# IAM ROLE - Worker (Consommer messages)
# ============================================================================
resource "aws_iam_role" "worker_sqs" {
  name = "${var.project_name}-worker-sqs-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  
  tags = {
    Name = "${var.project_name}-worker-sqs-role"
  }
}

resource "aws_iam_role_policy_attachment" "worker_sqs_consume" {
  role       = aws_iam_role.worker_sqs.name
  policy_arn = aws_iam_policy.sqs_consume.arn
}

# ============================================================================
# CLOUDWATCH ALARMS - Monitoring SQS
# ============================================================================

# Alarm: Trop de messages dans la DLQ
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.project_name}-dlq-messages-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300  # 5 minutes
  statistic           = "Average"
  threshold           = 10
  alarm_description   = "Alert when DLQ has more than 10 messages"
  
  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }
  
  tags = {
    Name = "${var.project_name}-dlq-alarm"
  }
}

# Alarm: Queue principale trop pleine
resource "aws_cloudwatch_metric_alarm" "queue_depth" {
  alarm_name          = "${var.project_name}-queue-depth-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 1000
  alarm_description   = "Alert when main queue has more than 1000 messages"
  
  dimensions = {
    QueueName = aws_sqs_queue.main.name
  }
  
  tags = {
    Name = "${var.project_name}-queue-depth-alarm"
  }
}

# ============================================================================
# OUTPUTS
# ============================================================================
output "sqs_queue_url" {
  description = "URL de la queue SQS principale"
  value       = aws_sqs_queue.main.url
}

output "sqs_queue_arn" {
  description = "ARN de la queue SQS principale"
  value       = aws_sqs_queue.main.arn
}

output "sqs_dlq_url" {
  description = "URL de la Dead Letter Queue"
  value       = aws_sqs_queue.dlq.url
}

output "sqs_dlq_arn" {
  description = "ARN de la Dead Letter Queue"
  value       = aws_sqs_queue.dlq.arn
}

output "backend_sqs_role_arn" {
  description = "ARN du rôle IAM Backend pour SQS"
  value       = aws_iam_role.backend_sqs.arn
}

output "worker_sqs_role_arn" {
  description = "ARN du rôle IAM Worker pour SQS"
  value       = aws_iam_role.worker_sqs.arn
}
