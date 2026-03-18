#!/bin/bash

VPC_ID=vpc-0c4722c38da4a6a59
REGION=us-east-1

echo "🗑️  Force delete VPC $VPC_ID"

# 1. Supprimer TOUTES les Network Interfaces (ENI)
echo "→ Suppression ENIs..."
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'NetworkInterfaces[*].NetworkInterfaceId' \
  --output text --region $REGION | tr '\t' '\n' | while read ENI; do
    echo "  Deleting ENI: $ENI"
    aws ec2 delete-network-interface --network-interface-id $ENI --region $REGION 2>/dev/null || true
done

sleep 15

# 2. Supprimer NAT Gateways
echo "→ Suppression NAT Gateways..."
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$VPC_ID" \
  --query 'NatGateways[*].NatGatewayId' \
  --output text --region $REGION | tr '\t' '\n' | while read NAT; do
    echo "  Deleting NAT: $NAT"
    aws ec2 delete-nat-gateway --nat-gateway-id $NAT --region $REGION 2>/dev/null || true
done

sleep 60  # NAT prend du temps

# 3. Release Elastic IPs
echo "→ Release Elastic IPs..."
aws ec2 describe-addresses \
  --filters "Name=domain,Values=vpc" \
  --query 'Addresses[*].AllocationId' \
  --output text --region $REGION | tr '\t' '\n' | while read EIP; do
    echo "  Releasing EIP: $EIP"
    aws ec2 release-address --allocation-id $EIP --region $REGION 2>/dev/null || true
done

# 4. Détacher et supprimer Internet Gateway
echo "→ Suppression Internet Gateway..."
aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  --query 'InternetGateways[*].InternetGatewayId' \
  --output text --region $REGION | tr '\t' '\n' | while read IGW; do
    echo "  Detaching IGW: $IGW"
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC_ID --region $REGION 2>/dev/null || true
    echo "  Deleting IGW: $IGW"
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW --region $REGION 2>/dev/null || true
done

# 5. Supprimer Subnets
echo "→ Suppression Subnets..."
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[*].SubnetId' \
  --output text --region $REGION | tr '\t' '\n' | while read SUBNET; do
    echo "  Deleting Subnet: $SUBNET"
    aws ec2 delete-subnet --subnet-id $SUBNET --region $REGION 2>/dev/null || true
done

sleep 10

# 6. Supprimer Route Tables (sauf main)
echo "→ Suppression Route Tables..."
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' \
  --output text --region $REGION | tr '\t' '\n' | while read RT; do
    echo "  Deleting Route Table: $RT"
    aws ec2 delete-route-table --route-table-id $RT --region $REGION 2>/dev/null || true
done

# 7. Supprimer Security Groups (sauf default)
echo "→ Suppression Security Groups..."
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
  --output text --region $REGION | tr '\t' '\n' | while read SG; do
    echo "  Deleting SG: $SG"
    aws ec2 delete-security-group --group-id $SG --region $REGION 2>/dev/null || true
done

sleep 5

# 8. FINAL : Supprimer VPC
echo "→ Suppression VPC..."
aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION

echo "✅ VPC supprimé"

# Vérification
aws ec2 describe-vpcs --vpc-ids $VPC_ID --region $REGION 2>/dev/null || echo "✅ VPC n'existe plus"