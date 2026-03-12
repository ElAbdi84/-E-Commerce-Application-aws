# terraform/outputs.tf

output "vpc_id" {
  description = "ID du VPC"
  value       = aws_vpc.main.id
}

output "rds_endpoint" {
  description = "Endpoint RDS"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "s3_bucket_name" {
  description = "Nom du bucket S3"
  value       = aws_s3_bucket.products.id
}

output "eks_cluster_name" {
  description = "Nom du cluster EKS"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint du cluster EKS"
  value       = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Commande pour configurer kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ecr_repositories" {
  description = "URLs des repositories ECR"
  value = {
    for repo in aws_ecr_repository.repos :
    repo.name => repo.repository_url
  }
}
output "ecr_registry" {
  value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}