# terraform/main.tf

# ==================== MODULES EKS ====================


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  # VPC
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  # Endpoints publics/privés
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # ==================== IMPORTANT : ACCÈS UTILISATEUR ====================
  # Activer l'API d'accès EKS (plus besoin de aws-auth ConfigMap)
  enable_cluster_creator_admin_permissions = true
  
 

  # Addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  # Node Group
  eks_managed_node_groups = {
    ecommerce_nodes = {
      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      instance_types = [var.node_instance_type]
      capacity_type  = "ON_DEMAND"

      disk_size = var.node_disk_size

      # Subnets privés uniquement
      subnet_ids = aws_subnet.private[*].id

      # Security Group
      vpc_security_group_ids = [aws_security_group.eks_nodes.id]

      # Tags
      tags = {
        Name      = "${var.project_name}-eks-nodes"
        Component = "eks-workers"
      }
    }
  }

  # CloudWatch Logs
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # OIDC Provider (pour IRSA)
  enable_irsa = true

  tags = {
    Name = var.cluster_name
  }
}

# ==================== LOCALS ====================

locals {
  account_id = data.aws_caller_identity.current.account_id
  
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.additional_tags
  )
}

# ==================== DATA SOURCES ====================

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

