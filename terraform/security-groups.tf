# ==================================================================================
# ARCHITECTURE SECURITY GROUPS - KUBERNETES vs EC2 TRADITIONNEL
# ==================================================================================
#
# Dans une architecture Kubernetes (EKS), nous n'avons besoin QUE de 3 Security Groups :
#
#   1. SG-ALB           : Protège l'Application Load Balancer (point d'entrée Internet)
#   2. SG-EKS-Nodes     : Protège les Worker Nodes (qui hébergent TOUS les Pods)
#   3. SG-RDS           : Protège la base de données MySQL
#
# POURQUOI PAS DE SG SÉPARÉS POUR FRONTEND/BACKEND/WORKER ?
#
# → Dans Kubernetes, les Pods Frontend, Backend et Worker tournent sur les MÊMES 
#   Worker Nodes (machines EC2). Ils partagent donc le même Security Group (SG-EKS-Nodes).
#
# → Le SG-EKS-Nodes autorise les ports nécessaires pour TOUS les Pods :
#   - Port 80    : Accès ALB → Pods Frontend
#   - Port 5000  : Accès ALB → Pods Backend  
#   - All Traffic depuis lui-même : Communication inter-Pods
#
# → Cette approche est PLUS SIMPLE qu'une architecture EC2 traditionnelle où chaque
#   application (Frontend, Backend, Worker) tourne sur une machine séparée nécessitant
#   son propre Security Group.
#
# → Pour une isolation plus fine entre Pods, Kubernetes propose les Network Policies,
#   mais ce n'est pas nécessaire pour ce projet car tous les Pods sont de confiance.
#
# AVANTAGES :
#   ✅ Moins de Security Groups à gérer (3 vs 6 en architecture EC2)
#   ✅ Plus flexible : les Pods peuvent bouger librement entre Nodes
#   ✅ Simplifie la maintenance et le déploiement
#   ✅ Best practice Kubernetes recommandée par AWS
#
# ==================================================================================

# terraform/security-groups.tf

# ==================== SG ALB ====================

resource "aws_security_group" "alb" {
  name = "${var.project_name}-sg-alb"
  description      = "Security Group for Application Load Balancer"
  vpc_id           = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-sg-alb"
    }
  )
}

# ==================== SG RDS ====================

resource "aws_security_group" "rds" {
  name = "${var.project_name}-sg-rds"
  description      = "Security Group for RDS MySQL"
  vpc_id           = aws_vpc.main.id

  ingress {
    description     = "MySQL from EKS Nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  egress {
    description = "All traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-sg-rds"
    }
  )
}

# ==================== SG EKS NODES ====================

resource "aws_security_group" "eks_nodes" {
  name = "${var.project_name}-sg-eks-nodes"
  description      = "Security Group for EKS Worker Nodes"
  vpc_id           = aws_vpc.main.id

  # All traffic from self (inter-node communication)
  ingress {
    description = "All traffic from self"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # HTTPS from Control Plane
  ingress {
    description     = "HTTPS from Control Plane"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [module.eks.cluster_security_group_id]
  }

  # Kubelet from Control Plane
  ingress {
    description     = "Kubelet from Control Plane"
    from_port       = 1024
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [module.eks.cluster_security_group_id]
  }

  # HTTP from ALB (Frontend Pods)
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Backend API from ALB
  ingress {
    description     = "Backend API from ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-sg-eks-nodes"
    }
  )
}
