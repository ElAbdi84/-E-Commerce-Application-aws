#!/bin/bash

# ============================================================================
# Script de nettoyage complet de l'infrastructure E-Commerce PFE
# ============================================================================
# 
# Ce script supprime TOUTES les ressources AWS créées pour le projet
# Utiliser si Terraform destroy ne fonctionne pas
#
# Usage: bash cleanup-all.sh
# ============================================================================

set -e  # Arrêter si erreur

REGION="us-east-1"
CLUSTER_NAME="ecommerce-cluster"
DB_IDENTIFIER="ecommerce-pfe-db"
VPC_NAME="ecommerce-pfe-vpc"
PROJECT_NAME="ecommerce-pfe"

echo "================================================"
echo "🗑️  NETTOYAGE COMPLET INFRASTRUCTURE"
echo "================================================"
echo ""
echo "⚠️  ATTENTION : Ceci va supprimer TOUTES les ressources !"
echo ""
read -p "Tapez 'yes' pour continuer: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Annulé"
    exit 0
fi

echo ""
echo "🚀 Début du nettoyage..."
echo ""

# ============================================================================
# 1. SUPPRIMER EKS CLUSTER
# ============================================================================
echo "📦 1/10 - Suppression EKS Cluster..."

# Lister et supprimer les Node Groups
echo "  → Suppression des Node Groups..."
NODE_GROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --query 'nodegroups' --output text 2>/dev/null || echo "")

if [ ! -z "$NODE_GROUPS" ]; then
    for NG in $NODE_GROUPS; do
        echo "    Suppression Node Group: $NG"
        aws eks delete-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $NG --region $REGION 2>/dev/null || true
    done
    
    echo "  ⏳ Attente suppression Node Groups (3-5 min)..."
    sleep 180
fi

# Supprimer le cluster
echo "  → Suppression du Cluster EKS..."
aws eks delete-cluster --name $CLUSTER_NAME --region $REGION 2>/dev/null || echo "  ⚠️  Cluster déjà supprimé ou n'existe pas"

echo "  ⏳ Attente suppression Cluster (2-3 min)..."
sleep 120

echo "✅ EKS Cluster supprimé"
echo ""

# ============================================================================
# 2. SUPPRIMER RDS DATABASE
# ============================================================================
echo "🗄️  2/10 - Suppression RDS Database..."

aws rds delete-db-instance \
    --db-instance-identifier $DB_IDENTIFIER \
    --skip-final-snapshot \
    --region $REGION 2>/dev/null || echo "  ⚠️  Database déjà supprimée ou n'existe pas"

echo "  ⏳ Attente suppression Database (3-5 min)..."
sleep 180

echo "✅ RDS Database supprimée"
echo ""

# ============================================================================
# 3. SUPPRIMER LOAD BALANCERS
# ============================================================================
echo "⚖️  3/10 - Suppression Load Balancers..."

LBS=$(aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[?contains(LoadBalancerName, `k8s`) == `true`].LoadBalancerArn' --output text 2>/dev/null || echo "")

if [ ! -z "$LBS" ]; then
    for LB in $LBS; do
        echo "  → Suppression ALB: $LB"
        aws elbv2 delete-load-balancer --load-balancer-arn $LB --region $REGION 2>/dev/null || true
    done
    sleep 30
fi

echo "✅ Load Balancers supprimés"
echo ""

# ============================================================================
# 4. SUPPRIMER NAT GATEWAYS
# ============================================================================
echo "🌐 4/10 - Suppression NAT Gateways..."

VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$VPC_NAME" --query 'Vpcs[0].VpcId' --output text --region $REGION 2>/dev/null || echo "")

if [ "$VPC_ID" != "" ] && [ "$VPC_ID" != "None" ]; then
    NAT_GWS=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[*].NatGatewayId' --output text --region $REGION 2>/dev/null || echo "")
    
    if [ ! -z "$NAT_GWS" ]; then
        for NAT in $NAT_GWS; do
            echo "  → Suppression NAT Gateway: $NAT"
            aws ec2 delete-nat-gateway --nat-gateway-id $NAT --region $REGION 2>/dev/null || true
        done
        sleep 60
    fi
fi

echo "✅ NAT Gateways supprimés"
echo ""

# ============================================================================
# 5. SUPPRIMER ELASTIC IPS
# ============================================================================
echo "🔌 5/10 - Suppression Elastic IPs..."

EIPS=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=*$PROJECT_NAME*" --query 'Addresses[*].AllocationId' --output text --region $REGION 2>/dev/null || echo "")

if [ ! -z "$EIPS" ]; then
    for EIP in $EIPS; do
        echo "  → Suppression EIP: $EIP"
        aws ec2 release-address --allocation-id $EIP --region $REGION 2>/dev/null || true
    done
fi

echo "✅ Elastic IPs supprimés"
echo ""

# ============================================================================
# 6. SUPPRIMER INTERNET GATEWAY
# ============================================================================
echo "🌍 6/10 - Suppression Internet Gateway..."

if [ "$VPC_ID" != "" ] && [ "$VPC_ID" != "None" ]; then
    IGW=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text --region $REGION 2>/dev/null || echo "")
    
    if [ "$IGW" != "" ] && [ "$IGW" != "None" ]; then
        echo "  → Détachement IGW..."
        aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC_ID --region $REGION 2>/dev/null || true
        
        echo "  → Suppression IGW..."
        aws ec2 delete-internet-gateway --internet-gateway-id $IGW --region $REGION 2>/dev/null || true
    fi
fi

echo "✅ Internet Gateway supprimé"
echo ""

# ============================================================================
# 7. SUPPRIMER SUBNETS
# ============================================================================
echo "🔲 7/10 - Suppression Subnets..."

if [ "$VPC_ID" != "" ] && [ "$VPC_ID" != "None" ]; then
    SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text --region $REGION 2>/dev/null || echo "")
    
    if [ ! -z "$SUBNETS" ]; then
        for SUBNET in $SUBNETS; do
            echo "  → Suppression Subnet: $SUBNET"
            aws ec2 delete-subnet --subnet-id $SUBNET --region $REGION 2>/dev/null || true
        done
    fi
fi

echo "✅ Subnets supprimés"
echo ""

# ============================================================================
# 8. SUPPRIMER ROUTE TABLES
# ============================================================================
echo "🗺️  8/10 - Suppression Route Tables..."

if [ "$VPC_ID" != "" ] && [ "$VPC_ID" != "None" ]; then
    RTS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=false" --query 'RouteTables[*].RouteTableId' --output text --region $REGION 2>/dev/null || echo "")
    
    if [ ! -z "$RTS" ]; then
        for RT in $RTS; do
            echo "  → Suppression Route Table: $RT"
            aws ec2 delete-route-table --route-table-id $RT --region $REGION 2>/dev/null || true
        done
    fi
fi

echo "✅ Route Tables supprimées"
echo ""

# ============================================================================
# 9. SUPPRIMER SECURITY GROUPS
# ============================================================================
echo "🔒 9/10 - Suppression Security Groups..."

if [ "$VPC_ID" != "" ] && [ "$VPC_ID" != "None" ]; then
    SGS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text --region $REGION 2>/dev/null || echo "")
    
    if [ ! -z "$SGS" ]; then
        for SG in $SGS; do
            echo "  → Suppression Security Group: $SG"
            aws ec2 delete-security-group --group-id $SG --region $REGION 2>/dev/null || true
        done
    fi
fi

echo "✅ Security Groups supprimés"
echo ""

# ============================================================================
# 10. SUPPRIMER VPC
# ============================================================================
echo "🏗️  10/10 - Suppression VPC..."

if [ "$VPC_ID" != "" ] && [ "$VPC_ID" != "None" ]; then
    echo "  → Suppression VPC: $VPC_ID"
    aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION 2>/dev/null || echo "  ⚠️  VPC déjà supprimé"
fi

echo "✅ VPC supprimé"
echo ""

# ============================================================================
# VÉRIFICATION FINALE
# ============================================================================
echo "================================================"
echo "🔍 VÉRIFICATION FINALE"
echo "================================================"
echo ""

# Vérifier EKS
echo "EKS Clusters:"
aws eks list-clusters --region $REGION --query 'clusters' --output text | grep $CLUSTER_NAME || echo "  ✅ Aucun cluster EKS"

# Vérifier RDS
echo ""
echo "RDS Instances:"
aws rds describe-db-instances --region $REGION --query 'DBInstances[*].DBInstanceIdentifier' --output text | grep $DB_IDENTIFIER || echo "  ✅ Aucune instance RDS"

# Vérifier VPC
echo ""
echo "VPCs:"
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$VPC_NAME" --region $REGION --query 'Vpcs[*].VpcId' --output text | grep vpc- || echo "  ✅ Aucun VPC ecommerce"

echo ""
echo "================================================"
echo "✅ NETTOYAGE COMPLET TERMINÉ !"
echo "================================================"
echo ""
echo "💰 Coût AWS estimé : ~$0/mois"
echo ""
echo "⚠️  CONSERVÉES (à supprimer manuellement si besoin):"
echo "  - S3 Bucket: ecommerce-products-oumaymaelabdi-2026"
echo "  - ECR Repositories (ecommerce-backend, ecommerce-frontend, ecommerce-worker)"
echo ""