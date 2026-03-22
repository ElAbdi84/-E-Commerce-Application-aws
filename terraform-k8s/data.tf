# terraform-k8s/data.tf

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

# ==================== RÉCUPÉRATION AUTOMATIQUE DEPUIS PHASE 1 ====================

# RDS Instance
data "aws_db_instance" "main" {
  db_instance_identifier = "${var.project_name}-db"
}

# S3 Bucket
data "aws_s3_bucket" "products" {
  bucket = var.s3_bucket_name
}

# VPC
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-vpc"]
  }
}

# Security Group ALB
data "aws_security_group" "alb" {
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-sg-alb"]
  }
  
  vpc_id = data.aws_vpc.main.id
}

# Subnets Publics
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-public-*"]
  }
}

# IAM Role pour ALB Controller
data "aws_iam_role" "alb_controller" {
  name = "${var.project_name}-alb-controller-role"
}

# Data source pour récupérer l'URL de la queue SQS
data "aws_sqs_queue" "main" {
  name = "${var.project_name}-queue"
}

data "aws_ecr_repository" "worker" {
  name = "ecommerce-worker"
}

# ==================== DATA SOURCES ====================

data "aws_eks_cluster" "main" {
  name = var.cluster_name
}

data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}

data "aws_iam_policy" "fluentbit_cloudwatch" {
  name = "${var.project_name}-fluentbit-cloudwatch"
}