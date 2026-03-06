# terraform/variables.tf

# ==================== GÉNÉRAL ====================

variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "ecommerce-pfe"
}

variable "environment" {
  description = "Environnement (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Région AWS"
  type        = string
  default     = "us-east-1"
}

# ==================== VPC ====================

variable "vpc_cidr" {
  description = "CIDR block pour le VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability Zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# ==================== EKS ====================

variable "cluster_name" {
  description = "Nom du cluster EKS"
  type        = string
  default     = "ecommerce-cluster"
}

variable "kubernetes_version" {
  description = "Version de Kubernetes"
  type        = string
  default     = "1.31"
}

variable "node_instance_type" {
  description = "Type d'instance pour les Worker Nodes"
  type        = string
  default     = "t3.small"
}

variable "node_desired_size" {
  description = "Nombre souhaité de Worker Nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Nombre minimum de Worker Nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Nombre maximum de Worker Nodes"
  type        = number
  default     = 5
}

variable "node_disk_size" {
  description = "Taille du disque des Worker Nodes (GB)"
  type        = number
  default     = 20
}

# ==================== RDS ====================

variable "db_instance_class" {
  description = "Classe d'instance RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Nom de la base de données"
  type        = string
  default     = "ecommerce"
}

variable "db_username" {
  description = "Nom d'utilisateur de la base de données"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Mot de passe de la base de données"
  type        = string
  sensitive   = true
}

variable "db_allocated_storage" {
  description = "Stockage alloué pour RDS (GB)"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "Version du moteur MySQL"
  type        = string
  default     = "8.0.35"
}

# ==================== S3 ====================

variable "s3_bucket_name" {
  description = "Nom du bucket S3 pour les images produits"
  type        = string
}

# ==================== SECRETS ====================

variable "jwt_secret" {
  description = "Secret pour JWT"
  type        = string
  sensitive   = true
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID pour S3"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key pour S3"
  type        = string
  sensitive   = true
}

# ==================== ECR ====================

variable "ecr_repositories" {
  description = "Liste des repositories ECR à créer"
  type        = list(string)
  default     = ["ecommerce-backend", "ecommerce-frontend", "ecommerce-worker"]
}

# ==================== TAGS ====================

variable "additional_tags" {
  description = "Tags additionnels à appliquer"
  type        = map(string)
  default     = {}
}
