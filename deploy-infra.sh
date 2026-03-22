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

# PHASE 6: CloudWatch Dashboard
echo -e "${BLUE}📊 Phase 6: CloudWatch Dashboard${NC}"
REGION="us-east-1"
PROJECT_NAME="ecommerce-pfe-elabdi"
QUEUE_NAME="ecommerce-pfe-elabdi-queue"  # ✅ AJOUTER nom queue
ALB_ARN=$(aws elbv2 describe-load-balancers --region $REGION \
  --query 'LoadBalancers[?contains(LoadBalancerName, `k8s`)].LoadBalancerArn' \
  --output text 2>/dev/null || echo "")
ALB_NAME=$(aws elbv2 describe-load-balancers --region $REGION \
  --query 'LoadBalancers[?contains(LoadBalancerName, `k8s`)].LoadBalancerName' \
  --output text 2>/dev/null || echo "")

if [ -n "$ALB_NAME" ]; then
  echo "  → ALB trouvé: $ALB_NAME"
  echo "  → Queue SQS: $QUEUE_NAME"
  
  aws cloudwatch put-dashboard \
    --dashboard-name "${PROJECT_NAME}-monitoring" \
    --region $REGION \
    --dashboard-body "{
      \"widgets\": [
        {
          \"type\": \"metric\",
          \"x\": 0,
          \"y\": 0,
          \"width\": 12,
          \"height\": 6,
          \"properties\": {
            \"metrics\": [
              [ \"AWS/ApplicationELB\", \"RequestCount\", { \"stat\": \"Sum\", \"label\": \"Requests\" } ],
              [ \".\", \"TargetResponseTime\", { \"stat\": \"Average\", \"label\": \"Latency (avg)\", \"yAxis\": \"right\" } ]
            ],
            \"view\": \"timeSeries\",
            \"stacked\": false,
            \"region\": \"${REGION}\",
            \"title\": \"ALB - Traffic & Latency\",
            \"period\": 300,
            \"yAxis\": {
              \"left\": { \"label\": \"Requests\" },
              \"right\": { \"label\": \"Seconds\" }
            }
          }
        },
        {
          \"type\": \"metric\",
          \"x\": 12,
          \"y\": 0,
          \"width\": 12,
          \"height\": 6,
          \"properties\": {
            \"metrics\": [
              [ \"AWS/ApplicationELB\", \"HTTPCode_Target_2XX_Count\", { \"stat\": \"Sum\", \"label\": \"2xx (Success)\", \"color\": \"#2ca02c\" } ],
              [ \".\", \"HTTPCode_Target_4XX_Count\", { \"stat\": \"Sum\", \"label\": \"4xx (Client Error)\", \"color\": \"#ff7f0e\" } ],
              [ \".\", \"HTTPCode_Target_5XX_Count\", { \"stat\": \"Sum\", \"label\": \"5xx (Server Error)\", \"color\": \"#d62728\" } ]
            ],
            \"view\": \"timeSeries\",
            \"stacked\": false,
            \"region\": \"${REGION}\",
            \"title\": \"ALB - HTTP Status Codes\",
            \"period\": 300
          }
        },
        {
          \"type\": \"metric\",
          \"x\": 0,
          \"y\": 6,
          \"width\": 12,
          \"height\": 6,
          \"properties\": {
            \"metrics\": [
              [ \"AWS/SQS\", \"NumberOfMessagesSent\", { \"stat\": \"Sum\", \"label\": \"Messages Sent\", \"color\": \"#1f77b4\" }, { \"QueueName\": \"${QUEUE_NAME}\" } ],
              [ \".\", \"NumberOfMessagesReceived\", { \"stat\": \"Sum\", \"label\": \"Messages Received\", \"color\": \"#ff7f0e\" }, { \"QueueName\": \"${QUEUE_NAME}\" } ],
              [ \".\", \"ApproximateNumberOfMessagesVisible\", { \"stat\": \"Average\", \"label\": \"Messages in Queue\", \"color\": \"#2ca02c\" }, { \"QueueName\": \"${QUEUE_NAME}\" } ]
            ],
            \"view\": \"timeSeries\",
            \"stacked\": false,
            \"region\": \"${REGION}\",
            \"title\": \"SQS - ${QUEUE_NAME}\",
            \"period\": 60,
            \"yAxis\": {
              \"left\": { \"min\": 0 }
            }
          }
        },
        {
          \"type\": \"metric\",
          \"x\": 12,
          \"y\": 6,
          \"width\": 12,
          \"height\": 6,
          \"properties\": {
            \"metrics\": [
              [ \"AWS/RDS\", \"CPUUtilization\", { \"stat\": \"Average\", \"label\": \"RDS CPU %\" } ],
              [ \".\", \"DatabaseConnections\", { \"stat\": \"Average\", \"label\": \"DB Connections\", \"yAxis\": \"right\" } ]
            ],
            \"view\": \"timeSeries\",
            \"stacked\": false,
            \"region\": \"${REGION}\",
            \"title\": \"RDS - Database Metrics\",
            \"period\": 300,
            \"yAxis\": {
              \"left\": { \"min\": 0, \"max\": 100, \"label\": \"CPU %\" },
              \"right\": { \"label\": \"Connections\" }
            }
          }
        },
        {
          \"type\": \"log\",
          \"x\": 0,
          \"y\": 12,
          \"width\": 12,
          \"height\": 6,
          \"properties\": {
            \"query\": \"SOURCE '/aws/eks/${CLUSTER_NAME}/backend'\\n| fields @timestamp, @message\\n| filter @message like /ERROR/\\n| sort @timestamp desc\\n| limit 20\",
            \"region\": \"${REGION}\",
            \"title\": \"Backend - Recent Errors\",
            \"stacked\": false
          }
        },
        {
          \"type\": \"log\",
          \"x\": 12,
          \"y\": 12,
          \"width\": 12,
          \"height\": 6,
          \"properties\": {
            \"query\": \"SOURCE '/aws/eks/${CLUSTER_NAME}/worker'\\n| fields @timestamp, @message\\n| filter @message like /WORKER/\\n| sort @timestamp desc\\n| limit 20\",
            \"region\": \"${REGION}\",
            \"title\": \"Worker - Recent Activity\",
            \"stacked\": false
          }
        }
      ]
    }" 2>/dev/null && echo "  ✅ Dashboard créé avec métriques SQS" || echo "  ⚠️  Erreur création dashboard (non bloquant)"
  
  DASHBOARD_URL="https://console.aws.amazon.com/cloudwatch/home?region=${REGION}#dashboards:name=${PROJECT_NAME}-monitoring"
  echo -e "${GREEN}  📊 Dashboard: ${DASHBOARD_URL}${NC}"
else
  echo "  ⚠️  ALB non trouvé, dashboard non créé"
fi

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