#!/bin/bash

# ============================================================================
# DEPLOY-INFRA : Déploiement Infrastructure Complète
# ============================================================================
# Usage: ./deploy-infra.sh
# Durée: 15-20 minutes
# ============================================================================

set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo ""
echo -e "${BLUE}🚀 DÉPLOIEMENT INFRASTRUCTURE E-COMMERCE PFE${NC}"
echo ""

# Vérifications
command -v aws &> /dev/null || { echo -e "${RED}❌ AWS CLI manquant${NC}"; exit 1; }
command -v terraform &> /dev/null || { echo -e "${RED}❌ Terraform manquant${NC}"; exit 1; }
command -v kubectl &> /dev/null || { echo -e "${RED}❌ kubectl manquant${NC}"; exit 1; }
aws sts get-caller-identity &> /dev/null || { echo -e "${RED}❌ AWS non configuré${NC}"; exit 1; }

echo -e "${GREEN}✅ Vérifications OK${NC}"
echo ""
read -p "Déployer l'infrastructure ? (yes/no) " -r
[[ ! $REPLY =~ ^[Yy]es$ ]] && exit 0

# PHASE 1: Terraform AWS
echo -e "${BLUE}📦 Phase 1: Infrastructure AWS${NC}"
cd terraform
terraform init && terraform apply -auto-approve
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
ECR_REGISTRY=$(terraform output -raw ecr_registry)
cd ..
sleep 120

# Configure kubectl
aws eks update-kubeconfig --name $CLUSTER_NAME --region us-east-1
kubectl get nodes

# PHASE 2: Terraform K8s
echo -e "${BLUE}☸️  Phase 2: Ressources Kubernetes${NC}"
helm repo add eks https://aws.github.io/eks-charts
helm repo update
cd terraform-k8s
terraform init && terraform apply -auto-approve
cd ..
sleep 60

# PHASE 3: Docker Images
echo -e "${BLUE}🐳 Phase 3: Images Docker${NC}"
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY

cd backend && docker build -t $ECR_REGISTRY/ecommerce-backend:latest . && docker push $ECR_REGISTRY/ecommerce-backend:latest && cd ..
cd frontend && docker build -t $ECR_REGISTRY/ecommerce-frontend:latest . && docker push $ECR_REGISTRY/ecommerce-frontend:latest && cd ..
cd worker && docker build -t $ECR_REGISTRY/ecommerce-worker:latest . && docker push $ECR_REGISTRY/ecommerce-worker:latest && cd ..

# PHASE 4: Deploy Apps
echo -e "${BLUE}🚀 Phase 4: Deploy Applications${NC}"
kubectl rollout restart deployment/backend-deployment deployment/frontend-deployment
kubectl rollout status deployment/backend-deployment --timeout=5m
kubectl rollout status deployment/frontend-deployment --timeout=5m

# ✅ RESTART WORKER (après que l'image soit buildée)
echo -e "${BLUE}🔄 Restart Worker (nouvelle image disponible)${NC}"
kubectl delete pod -l app=worker --ignore-not-found=true
sleep 10
kubectl rollout status deployment/worker-deployment --timeout=5m || echo -e "${YELLOW}⚠️  Worker en cours de démarrage (vérifier manuellement)${NC}"

# PHASE 5: Init DB
echo -e "${BLUE}🗄️  Phase 5: Database${NC}"
sleep 30
BACKEND_POD=$(kubectl get pod -l app=backend -o jsonpath='{.items[0].metadata.name}')
kubectl cp backend/init-db.js $BACKEND_POD:/app/init-db.js
kubectl exec $BACKEND_POD -- node init-db.js || true

# Résultat
echo ""
echo -e "${GREEN}🎉 DÉPLOIEMENT RÉUSSI !${NC}"
APP_URL=$(kubectl get ingress ecommerce-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo -e "${BLUE}🌍 URL: http://$APP_URL${NC}"
echo ""

# Afficher URL SQS
cd terraform
SQS_QUEUE_URL=$(terraform output -raw sqs_queue_url 2>/dev/null || echo "Non disponible")
echo -e "${YELLOW}📬 Queue SQS: $SQS_QUEUE_URL${NC}"
cd ..
echo ""

kubectl get pods