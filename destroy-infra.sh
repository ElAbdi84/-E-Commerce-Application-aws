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

echo ""
echo -e "${GREEN}✅ Infrastructure détruite${NC}"
echo -e "${YELLOW}💰 Coût AWS: ~$0/mois${NC}"
echo ""