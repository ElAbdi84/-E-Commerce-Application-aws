# Terraform Phase 2 - Ressources Kubernetes

## 📋 Vue d'Ensemble

Ce dossier contient la **Phase 2** du déploiement Terraform : les ressources Kubernetes.

**Phase 1** (`terraform/`) doit être appliquée AVANT cette phase.

---

## 🎯 Ce Qui Est Créé

- ✅ **Secrets Kubernetes** (DB, JWT, AWS)
- ✅ **ConfigMap** (variables d'environnement)
- ✅ **Deployments** (Backend, Frontend, Worker)
- ✅ **Services** (Backend, Frontend)
- ✅ **Ingress ALB** (Load Balancer public)
- ✅ **HPA** (Auto-scaling Backend et Frontend)
- ✅ **ALB Controller** (via Helm)

---

## ✅ Prérequis

```bash
# 1. Phase 1 doit être complétée
cd ~/ecommerce-pfe/terraform
terraform apply  # Déjà fait

# 2. kubectl configuré
aws eks update-kubeconfig --region us-east-1 --name ecommerce-cluster
kubectl get nodes  # Doit fonctionner

# 3. Images Docker dans ECR
# (Build et push des 3 images : backend, frontend, worker)
```

---

## 🚀 Déploiement

### **Étape 1 : Créer terraform.tfvars**

```bash
cd ~/ecommerce-pfe/terraform-k8s

# Copier le template
cp terraform.tfvars.template terraform.tfvars

# Éditer avec vos valeurs
nano terraform.tfvars
```

**Remplir :**
- `s3_bucket_name` : Nom exact du bucket (Phase 1)
- `db_password` : Même que Phase 1
- `jwt_secret` : Même que Phase 1
- `aws_access_key_id` : Même que Phase 1
- `aws_secret_access_key` : Même que Phase 1

### **Étape 2 : Initialiser**

```bash
terraform init
```

### **Étape 3 : Valider**

```bash
terraform validate
```

### **Étape 4 : Plan**

```bash
terraform plan
```

**Vérifier :**
- ~15 ressources à créer
- Les data sources récupèrent bien les infos (RDS endpoint, VPC ID, etc.)

### **Étape 5 : Appliquer**

```bash
terraform apply
```

**Durée : 5-10 minutes**

---

## 📊 Vérifications

```bash
# Pods
kubectl get pods

# Services
kubectl get services

# Ingress (attendre 2-3 min)
kubectl get ingress ecommerce-ingress

# HPA
kubectl get hpa

# URL de l'application
kubectl get ingress ecommerce-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

## 🔍 Récupération Automatique

Les informations suivantes sont **récupérées automatiquement** depuis Phase 1 :

- ✅ VPC ID
- ✅ Subnets publics
- ✅ Security Group ALB
- ✅ RDS Endpoint
- ✅ S3 Bucket
- ✅ IAM Role ALB Controller

**Aucun copier-coller manuel nécessaire !** 🎉

---

## 🗑️ Suppression

```bash
# Supprimer les ressources Kubernetes
terraform destroy

# Puis supprimer l'infrastructure AWS (Phase 1)
cd ~/ecommerce-pfe/terraform
terraform destroy
```

---

## 📚 Structure

```
terraform-k8s/
├── versions.tf                 # Providers
├── variables.tf                # Variables
├── terraform.tfvars.template   # Template valeurs
├── data.tf                     # Data sources (récupération auto)
├── kubernetes-resources.tf     # Deployments, Services, Ingress, HPA
├── alb-controller.tf           # ALB Controller Helm
├── outputs.tf                  # Outputs
├── .gitignore                  # Git ignore
└── README.md                   # Ce fichier
```

---

## 🎓 Pour la Soutenance

**"J'ai séparé Terraform en 2 phases :**

- **Phase 1 (terraform/)** : Infrastructure AWS (VPC, EKS, RDS, S3)
- **Phase 2 (terraform-k8s/)** : Ressources Kubernetes (Pods, Services, Ingress)

**Cette séparation permet :**
1. Gérer le cycle de vie différent entre infra AWS et ressources K8s
2. Éviter les problèmes d'authentification provider Kubernetes
3. Faciliter les mises à jour (redéployer K8s sans toucher à l'infra)
4. Suivre les best practices Terraform (séparation des responsabilités)

**Les data sources Terraform récupèrent automatiquement les infos de Phase 1, évitant tout copier-coller manuel."**

---

**Auteur** : Oumayma El Abdi  
**Date** : Mars 2026  
**Version** : 1.0