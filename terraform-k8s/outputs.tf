# terraform-k8s/outputs.tf

output "namespace" {
  description = "Namespace utilisé"
  value       = "default"
}

output "get_pods" {
  description = "Commande pour voir les Pods"
  value       = "kubectl get pods"
}

output "get_ingress_url" {
  description = "Commande pour obtenir l'URL ALB"
  value       = "kubectl get ingress ecommerce-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "db_endpoint_from_phase1" {
  description = "Endpoint RDS récupéré automatiquement"
  value       = data.aws_db_instance.main.endpoint
  sensitive   = true
}

output "s3_bucket_from_phase1" {
  description = "Bucket S3 récupéré automatiquement"
  value       = data.aws_s3_bucket.products.id
}