#!/bin/bash

# ============================================================================
# DESTROY-INFRA : Destruction Infrastructure Complète
# ============================================================================
# Usage: ./destroy-infra.sh
# Durée: 8-12 minutes
# ============================================================================

set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo ""
echo -e "${RED}🗑️  DESTRUCTION INFRASTRUCTURE${NC}"
echo ""
echo -e "${YELLOW}⚠️  ATTENTION : Ceci va TOUT supprimer !${NC}"
echo ""
read -p "Taper 'DESTROY' pour confirmer: " CONFIRM

if [ "$CONFIRM" != "DESTROY" ]; then
    echo -e "${GREEN}❌ Annulé${NC}"
    exit 0
fi

echo ""
echo -e "${RED}🗑️  Destruction en cours...${NC}"

# ============================================================================
# PHASE -1: NETTOYAGE PRÉ-DESTROY
# ============================================================================
echo -e "${BLUE}Phase -1: Nettoyage Pré-Destroy${NC}"

# Vider ECR Repositories
echo "  → Vidage ECR Repositories..."
for repo in ecommerce-frontend ecommerce-backend ecommerce-worker; do
  IMAGE_IDS=$(aws ecr list-images --repository-name $repo --region us-east-1 \
    --query 'imageIds[*]' --output json 2>/dev/null || echo "[]")
  
  if [ "$IMAGE_IDS" != "[]" ]; then
    echo "    Suppression images dans $repo..."
    aws ecr batch-delete-image \
      --repository-name $repo \
      --image-ids "$IMAGE_IDS" \
      --region us-east-1 2>/dev/null || true
  fi
done

# Détacher IAM Policy FluentBit de tous les rôles
echo "  → Détachement IAM Policy FluentBit..."
POLICY_ARN="arn:aws:iam::714454206137:policy/ecommerce-pfe-elabdi-fluentbit-cloudwatch"
ATTACHED_ROLES=$(aws iam list-entities-for-policy --policy-arn $POLICY_ARN \
  --query 'PolicyRoles[*].RoleName' --output text 2>/dev/null || echo "")

for ROLE in $ATTACHED_ROLES; do
  echo "    Détachement du rôle $ROLE..."
  aws iam detach-role-policy --role-name $ROLE --policy-arn $POLICY_ARN 2>/dev/null || true
done

# ============================================================================
# PHASE 0: NETTOYAGE KUBERNETES
# ============================================================================
echo -e "${BLUE}Phase 0: Nettoyage Kubernetes${NC}"
kubectl delete namespace logging --ignore-not-found=true 2>/dev/null || true
echo "  → Namespace logging supprimé"

# ============================================================================
# PHASE 1: TERRAFORM KUBERNETES
# ============================================================================
echo -e "${BLUE}Phase 1: Terraform Kubernetes${NC}"
cd terraform-k8s
terraform destroy -auto-approve || true
cd ..

# ============================================================================
# PHASE 2: TERRAFORM AWS
# ============================================================================
echo -e "${BLUE}Phase 2: Terraform AWS${NC}"
cd terraform
terraform destroy -auto-approve || true
cd ..

# ============================================================================
# PHASE 3: NETTOYAGE FINAL FORCÉ
# ============================================================================
echo ""
echo -e "${BLUE}🧹 Phase 3: Nettoyage Final Forcé${NC}"

# Supprimer Dashboard CloudWatch
echo "  → Suppression Dashboard CloudWatch..."
aws cloudwatch delete-dashboards \
  --dashboard-names ecommerce-pfe-elabdi-monitoring \
  --region us-east-1 2>/dev/null && echo "    ✅ Dashboard supprimé" || echo "    ⚠️  Dashboard non trouvé"

# Récupérer VPC ID
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=ecommerce-pfe-elabdi-vpc" \
  --query 'Vpcs[0].VpcId' \
  --output text --region us-east-1 2>/dev/null || echo "")

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
  echo "  → VPC trouvé: $VPC_ID"
  
  # 1. Supprimer NAT Gateways (bloquent subnets)
  echo "  → Suppression NAT Gateways..."
  NAT_IDS=$(aws ec2 describe-nat-gateways \
    --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
    --query 'NatGateways[*].NatGatewayId' \
    --output text --region us-east-1 2>/dev/null || echo "")
  
  for NAT in $NAT_IDS; do
    echo "    Suppression NAT Gateway: $NAT"
    aws ec2 delete-nat-gateway --nat-gateway-id $NAT --region us-east-1 2>/dev/null || true
  done
  
  if [ -n "$NAT_IDS" ]; then
    echo "    Attente suppression NAT Gateways (60s)..."
    sleep 60
  fi
  
  # 2. Release Elastic IPs
  echo "  → Release Elastic IPs..."
  EIP_IDS=$(aws ec2 describe-addresses \
    --filters "Name=domain,Values=vpc" \
    --query 'Addresses[*].AllocationId' \
    --output text --region us-east-1 2>/dev/null || echo "")
  
  for EIP in $EIP_IDS; do
    echo "    Release EIP: $EIP"
    aws ec2 release-address --allocation-id $EIP --region us-east-1 2>/dev/null || true
  done
  
  # 3. Supprimer Load Balancers (attachés aux subnets)
  echo "  → Suppression Load Balancers..."
  LB_ARNS=$(aws elbv2 describe-load-balancers \
    --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" \
    --output text --region us-east-1 2>/dev/null || echo "")
  
  for LB in $LB_ARNS; do
    echo "    Suppression ALB: $LB"
    aws elbv2 delete-load-balancer --load-balancer-arn $LB --region us-east-1 2>/dev/null || true
  done
  
  if [ -n "$LB_ARNS" ]; then
    echo "    Attente suppression ALB (30s)..."
    sleep 30
  fi
  
  # 4. Supprimer Network Interfaces
  echo "  → Suppression Network Interfaces..."
  NI_IDS=$(aws ec2 describe-network-interfaces \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'NetworkInterfaces[*].NetworkInterfaceId' \
    --output text --region us-east-1 2>/dev/null || echo "")
  
  for NI in $NI_IDS; do
    echo "    Suppression ENI: $NI"
    aws ec2 delete-network-interface --network-interface-id $NI --region us-east-1 2>/dev/null || true
  done
  
  sleep 15
  
  # 5. Détacher et supprimer Internet Gateway
  echo "  → Suppression Internet Gateway..."
  IGW=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text --region us-east-1 2>/dev/null || echo "")
  
  if [ -n "$IGW" ] && [ "$IGW" != "None" ]; then
    echo "    Détachement IGW: $IGW"
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC_ID --region us-east-1 2>/dev/null || true
    echo "    Suppression IGW: $IGW"
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW --region us-east-1 2>/dev/null || true
  fi
  
  # 6. Supprimer Subnets
  echo "  → Suppression Subnets..."
  SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[*].SubnetId' \
    --output text --region us-east-1 2>/dev/null || echo "")
  
  for SUBNET in $SUBNET_IDS; do
    echo "    Suppression Subnet: $SUBNET"
    aws ec2 delete-subnet --subnet-id $SUBNET --region us-east-1 2>/dev/null || true
  done
  
  sleep 10
  
  # 7. Supprimer Security Groups (sauf default)
  echo "  → Suppression Security Groups..."
  SG_IDS=$(aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
    --output text --region us-east-1 2>/dev/null || echo "")
  
  # Supprimer les règles d'abord (dépendances entre SG)
  for SG in $SG_IDS; do
    echo "    Suppression règles SG: $SG"
    aws ec2 revoke-security-group-ingress --group-id $SG --ip-permissions \
      "$(aws ec2 describe-security-groups --group-ids $SG --query 'SecurityGroups[0].IpPermissions' --output json)" \
      --region us-east-1 2>/dev/null || true
    aws ec2 revoke-security-group-egress --group-id $SG --ip-permissions \
      "$(aws ec2 describe-security-groups --group-ids $SG --query 'SecurityGroups[0].IpPermissionsEgress' --output json)" \
      --region us-east-1 2>/dev/null || true
  done
  
  sleep 5
  
  # Supprimer les SG
  for SG in $SG_IDS; do
    echo "    Suppression SG: $SG"
    aws ec2 delete-security-group --group-id $SG --region us-east-1 2>/dev/null || true
  done
  
  # 8. Supprimer VPC
  echo "  → Suppression VPC: $VPC_ID..."
  aws ec2 delete-vpc --vpc-id $VPC_ID --region us-east-1 2>/dev/null && echo "    ✅ VPC supprimé" || echo "    ⚠️  Erreur suppression VPC"
else
  echo "  → Aucun VPC à nettoyer"
fi

# Supprimer IAM Policy FluentBit (si détachée)
echo "  → Suppression IAM Policy FluentBit..."
aws iam delete-policy \
  --policy-arn arn:aws:iam::714454206137:policy/ecommerce-pfe-elabdi-fluentbit-cloudwatch \
  --region us-east-1 2>/dev/null && echo "    ✅ Policy supprimée" || echo "    ⚠️  Policy non trouvée"

echo ""
echo -e "${GREEN}✅ Infrastructure détruite${NC}"
echo -e "${YELLOW}💰 Coût AWS: ~\$0/mois${NC}"
echo ""