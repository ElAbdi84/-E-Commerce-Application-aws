#!/bin/bash

# ============================================================================
# DESTROY-INFRA : Destruction Infrastructure Complète
# ============================================================================
# Usage: ./destroy-infra.sh
# Durée: 8-12 minutes
# ============================================================================

set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

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

# Phase 1: Détruire Kubernetes resources
echo -e "${YELLOW}Phase 1: Kubernetes${NC}"
cd terraform-k8s
terraform destroy -auto-approve || true
cd ..

# Phase 2: Détruire AWS infrastructure  
echo -e "${YELLOW}Phase 2: AWS Infrastructure${NC}"
cd terraform
terraform destroy -auto-approve || true
cd ..

# ✅ NETTOYAGE FINAL AUTOMATIQUE
echo ""
echo -e "${YELLOW}🧹 Nettoyage final...${NC}"

# Récupérer VPC ID
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=ecommerce-pfe-elabdi-vpc" \
  --query 'Vpcs[0].VpcId' \
  --output text --region us-east-1 2>/dev/null || echo "")

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
  echo "  → VPC trouvé: $VPC_ID"
  
  # Supprimer Network Interfaces
  echo "  → Suppression Network Interfaces..."
  NI_IDS=$(aws ec2 describe-network-interfaces \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'NetworkInterfaces[*].NetworkInterfaceId' \
    --output text --region us-east-1 2>/dev/null || echo "")
  
  for NI in $NI_IDS; do
    aws ec2 delete-network-interface --network-interface-id $NI --region us-east-1 2>/dev/null || true
  done
  
  sleep 10
  
  # Supprimer Internet Gateway
  echo "  → Suppression Internet Gateway..."
  IGW=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text --region us-east-1 2>/dev/null || echo "")
  
  if [ -n "$IGW" ] && [ "$IGW" != "None" ]; then
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC_ID --region us-east-1 2>/dev/null || true
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW --region us-east-1 2>/dev/null || true
  fi
  
  # Supprimer Subnets
  echo "  → Suppression Subnets..."
  SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[*].SubnetId' \
    --output text --region us-east-1 2>/dev/null || echo "")
  
  for SUBNET in $SUBNET_IDS; do
    aws ec2 delete-subnet --subnet-id $SUBNET --region us-east-1 2>/dev/null || true
  done
  
  # Supprimer Security Groups (sauf default)
  echo "  → Suppression Security Groups..."
  SG_IDS=$(aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
    --output text --region us-east-1 2>/dev/null || echo "")
  
  sleep 5
  
  for SG in $SG_IDS; do
    aws ec2 delete-security-group --group-id $SG --region us-east-1 2>/dev/null || true
  done
  
  # Supprimer VPC
  echo "  → Suppression VPC..."
  aws ec2 delete-vpc --vpc-id $VPC_ID --region us-east-1 2>/dev/null || true
  echo "  → VPC supprimé"
else
  echo "  → Aucun VPC à nettoyer"
fi

echo ""
echo -e "${GREEN}✅ Infrastructure détruite${NC}"
echo -e "${YELLOW}💰 Coût AWS: ~\$0/mois${NC}"
echo ""