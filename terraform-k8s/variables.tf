# terraform-k8s/variables.tf

variable "aws_region" {
  description = "Région AWS"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nom du cluster EKS"
  type        = string
  default     = "ecommerce-cluster"
}

variable "environment" {
  description = "Environnement"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "ecommerce-pfe"
}

variable "s3_bucket_name" {
  description = "Nom du S3 Bucket"
  type        = string
}

# ==================== SECRETS ====================

variable "db_username" {
  description = "DB Username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "DB Password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "DB Name"
  type        = string
  default     = "ecommerce"
}

variable "jwt_secret" {
  description = "JWT Secret"
  type        = string
  sensitive   = true
}

variable "aws_access_key_id" {
  description = "AWS Access Key pour S3"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Key pour S3"
  type        = string
  sensitive   = true
}