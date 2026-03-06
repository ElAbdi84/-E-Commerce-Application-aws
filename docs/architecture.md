# 🏗️ Architecture Technique - Projet E-Commerce PFE

## 📋 Vue d'Ensemble

Ce document décrit l'architecture technique complète du projet e-commerce déployé sur AWS avec Kubernetes (EKS).

---

## 🎯 Architecture Globale

### **Stack Technologique**

```
Frontend  : React 18 + Nginx
Backend   : Node.js 18 + Express
Worker    : Node.js 18 (SQS Consumer)
Base de données : MySQL 8.0 (RDS)
Stockage  : Amazon S3
Registre  : Amazon ECR
Orchestration : Kubernetes (EKS)
Infrastructure : Terraform
CI/CD     : GitHub Actions (Partie 6)
```

---

## 🌐 Architecture Réseau (VPC)

### **Topologie Multi-AZ**

```
VPC 10.0.0.0/16 (us-east-1)
│
├── Subnets Publics (2 AZs)
│   ├── 10.0.1.0/24 (us-east-1a) → ALB, NAT Gateway
│   └── 10.0.2.0/24 (us-east-1b) → ALB Backup
│
└── Subnets Privés (2 AZs)
    ├── 10.0.3.0/24 (us-east-1a) → Worker Nodes, RDS
    └── 10.0.4.0/24 (us-east-1b) → Worker Nodes, RDS Backup
```

### **Composants Réseau**

| Composant | Description | Rôle |
|-----------|-------------|------|
| **Internet Gateway** | Point d'entrée Internet | Permet accès public à l'ALB |
| **NAT Gateway** | Accès sortant privé | Permet Nodes privés d'accéder Internet |
| **Route Tables** | Routage réseau | 1 publique + 1 privée |

---

## 🔐 Sécurité (Security Groups)

### **Architecture en Couches**

```
Internet (0.0.0.0/0)
    ↓ Port 80/443
┌─────────────────────────────────┐
│  SG-ALB (Application Load Balancer) │
└────────────┬────────────────────┘
             ↓ Port 80, 5000
┌─────────────────────────────────┐
│  SG-EKS-Nodes (Worker Nodes)    │
│  - Héberge TOUS les Pods        │
│  - Frontend, Backend, Worker    │
└────────────┬────────────────────┘
             ↓ Port 3306
┌─────────────────────────────────┐
│  SG-RDS (Base de données)       │
└─────────────────────────────────┘
```

### **Règles de Sécurité**

#### **SG-ALB**
- **Inbound** : Port 80 (HTTP) + 443 (HTTPS) depuis Internet
- **Outbound** : All Traffic

#### **SG-EKS-Nodes**
- **Inbound** :
  - Port 80 depuis SG-ALB (Frontend Pods)
  - Port 5000 depuis SG-ALB (Backend Pods)
  - All Traffic depuis lui-même (inter-Pods)
  - Ports 443, 1024-65535 depuis Control Plane
- **Outbound** : All Traffic

#### **SG-RDS**
- **Inbound** : Port 3306 depuis SG-EKS-Nodes uniquement
- **Outbound** : All Traffic

---

## ☸️ Architecture Kubernetes (EKS)

### **Cluster EKS**

```yaml
Nom : ecommerce-cluster
Version : Kubernetes 1.31
Région : us-east-1
VPC : 10.0.0.0/16
Worker Nodes : 2x t3.small (2 vCPU, 2 GB RAM chacun)
Capacity Type : ON_DEMAND
```

### **Node Group**

```yaml
Nom : ecommerce-nodes
Min Size : 2 nodes
Max Size : 5 nodes (HPA auto-scaling)
Desired : 2 nodes
Disk : 20 GB GP2 par node
Subnets : Privés uniquement (10.0.3.0/24, 10.0.4.0/24)
```

### **Addons Installés**

- **CoreDNS** : Résolution DNS interne
- **kube-proxy** : Gestion réseau Pods
- **VPC CNI** : Networking AWS (IPs Pods)
- **AWS Load Balancer Controller** : Création automatique ALB

---

## 🎯 Architecture Applicative

### **Microservices**

```
┌─────────────────────────────────────────────────┐
│               Application Load Balancer          │
│  URL: k8s-default-ecommerc-xxxxx.elb.amazonaws.com│
└────────────────┬────────────────────────────────┘
                 │
        ┌────────┴────────┐
        ↓                 ↓
┌───────────────┐  ┌──────────────┐
│   Frontend    │  │   Backend    │
│   (Nginx)     │  │   (Express)  │
│   2 replicas  │  │   2 replicas │
└───────────────┘  └──────┬───────┘
                          │
                ┌─────────┴─────────┐
                ↓                   ↓
        ┌───────────────┐   ┌──────────────┐
        │     RDS       │   │      S3      │
        │    MySQL      │   │   (Images)   │
        └───────────────┘   └──────────────┘
                
        ┌───────────────┐
        │    Worker     │
        │  (SQS Queue)  │
        │   1 replica   │
        └───────────────┘
```

---

## 📦 Détail des Composants

### **1. Frontend (React + Nginx)**

```yaml
Image : ecommerce-frontend:latest
Port : 80
Replicas : 2 (min) - 5 (max avec HPA)
Resources :
  Requests : 64Mi RAM, 50m CPU
  Limits : 128Mi RAM, 100m CPU
Health Checks :
  Liveness : GET / (20s delay)
  Readiness : GET / (5s delay)
```

**Fonctionnalités :**
- Interface utilisateur React 18
- Servie par Nginx (images Alpine)
- Proxy inverse vers Backend pour `/api/*`
- Build optimisé (production)

---

### **2. Backend (Node.js + Express)**

```yaml
Image : ecommerce-backend:latest
Port : 5000
Replicas : 2 (min) - 5 (max avec HPA)
Resources :
  Requests : 128Mi RAM, 100m CPU
  Limits : 256Mi RAM, 200m CPU
Health Checks :
  Liveness : GET /health (30s delay)
  Readiness : GET /health (10s delay)
```

**Fonctionnalités :**
- API REST (Express.js)
- Authentification JWT
- Upload images → S3
- Connexion RDS MySQL
- CORS configuré

**Endpoints Principaux :**
```
GET    /api/products          # Liste produits
GET    /api/products/:id      # Détail produit
POST   /api/products          # Créer produit (admin)
PUT    /api/products/:id      # Modifier produit (admin)
DELETE /api/products/:id      # Supprimer produit (admin)
GET    /api/categories        # Liste catégories
POST   /api/auth/login        # Connexion
POST   /api/auth/register     # Inscription
GET    /api/orders            # Commandes utilisateur
POST   /api/orders            # Créer commande
GET    /health                # Health check
```

---

### **3. Worker (Node.js SQS Consumer)**

```yaml
Image : ecommerce-worker:latest
Replicas : 1
Resources :
  Requests : 64Mi RAM, 50m CPU
  Limits : 128Mi RAM, 100m CPU
```

**Fonctionnalités :**
- Écoute queue SQS (Partie 7)
- Traitement asynchrone (emails, notifications)
- Aucun port exposé (pas de Service)

---

### **4. Base de Données (RDS MySQL)**

```yaml
Engine : MySQL 8.0.35
Instance : db.t3.micro (1 vCPU, 1 GB RAM)
Storage : 20 GB GP2
Multi-AZ : Non (Dev environment)
Backup : 7 jours de rétention
Encryption : Activé
Public Access : Non
Subnets : Privés uniquement
```

**Schéma Base de Données :**

```sql
Tables :
- users (id, email, password, role, created_at)
- categories (id, name, description)
- products (id, name, description, price, stock, image_url, category_id)
- orders (id, user_id, total, status, created_at)
- order_items (id, order_id, product_id, quantity, price)
- cart_items (id, user_id, product_id, quantity)
```

---

### **5. Stockage (S3)**

```yaml
Bucket : ecommerce-products-oumayma-2026
Versioning : Activé
Public Access : Bloqué (pré-signed URLs)
CORS : Configuré pour Frontend
Lifecycle : Pas de règle (conservation infinie)
```

**Usage :**
- Images produits uploadées par Backend
- Accès via IAM User credentials
- URLs pré-signées générées par Backend

---

### **6. Registre Docker (ECR)**

```yaml
Repositories :
- ecommerce-backend
- ecommerce-frontend
- ecommerce-worker

Scan : Activé (sécurité)
Lifecycle : Garde 10 dernières images
Mutability : MUTABLE (tags peuvent être écrasés)
```

---

## 🔄 Services Kubernetes

### **frontend-service**

```yaml
Type : ClusterIP (interne)
Port : 80
Target Port : 80 (Nginx)
Selector : app=frontend
```

### **backend-service**

```yaml
Type : ClusterIP (interne)
Port : 5000
Target Port : 5000 (Express)
Selector : app=backend
```

**Pas de Service pour Worker** (pas d'accès réseau nécessaire)

---

## 🌐 Ingress (ALB)

```yaml
Classe : alb
Scheme : internet-facing
Target Type : IP (Pods directement)
Subnets : Publics (10.0.1.0/24, 10.0.2.0/24)
Security Groups : SG-ALB

Règles :
  / → frontend-service:80
  /api → backend-service:5000

Health Checks :
  Path : /
  Protocol : HTTP
  Interval : 30s
  Timeout : 5s
  Healthy Threshold : 2
  Unhealthy Threshold : 2
```

---

## 📈 Auto-Scaling (HPA)

### **Backend HPA**

```yaml
Min Replicas : 2
Max Replicas : 5
Metrics :
  - CPU : 70% utilization
  - Memory : 80% utilization
Scale Down Stabilization : 5 minutes
Scale Up Policy : Immédiat
```

### **Frontend HPA**

```yaml
Min Replicas : 2
Max Replicas : 5
Metrics :
  - CPU : 70% utilization
  - Memory : 80% utilization
```

---

## 🔐 Gestion des Secrets

### **Kubernetes Secrets**

```yaml
db-credentials :
  - DB_HOST (endpoint RDS)
  - DB_USER (admin)
  - DB_PASSWORD (encrypted)
  - DB_NAME (ecommerce)
  - DB_PORT (3306)

jwt-secret :
  - JWT_SECRET (token signing)

aws-credentials :
  - AWS_ACCESS_KEY_ID (S3 access)
  - AWS_SECRET_ACCESS_KEY (S3 secret)
```

### **ConfigMap**

```yaml
app-config :
  - NODE_ENV=production
  - AWS_REGION=us-east-1
  - S3_BUCKET_NAME=ecommerce-products-xxx
  - BACKEND_PORT=5000
  - REACT_APP_API_URL=/api
```

---

## 💾 Persistance et Backups

### **Base de Données**
- **Backups automatiques** : 7 jours
- **Snapshots manuels** : Possibles
- **Point-in-time recovery** : 5 minutes

### **Images Docker**
- **ECR Lifecycle** : 10 dernières versions
- **Images taguées** : latest + git commit SHA

### **Logs**
- **CloudWatch Logs** : EKS Control Plane logs
- **Retention** : 7 jours par défaut

---

## 🌍 Haute Disponibilité

### **Multi-AZ**
- Subnets dans 2 Availability Zones
- Worker Nodes répartis (us-east-1a, us-east-1b)
- ALB distribue le trafic entre AZs

### **Réplication**
- Frontend : 2 Pods minimum
- Backend : 2 Pods minimum
- RDS : Pas de Multi-AZ (dev), mais backups activés

### **Self-Healing**
- Kubernetes redémarre automatiquement les Pods crashés
- ALB retire automatiquement les Pods unhealthy
- HPA scale automatiquement selon la charge

---

## 📊 Monitoring et Métriques

### **Kubernetes Metrics**
- **Metrics Server** : CPU/RAM des Pods et Nodes
- **kubectl top** : Consultation temps réel

### **AWS CloudWatch**
- **EKS Control Plane Logs** : API, Audit, Authenticator
- **RDS Metrics** : CPU, Connections, IOPS
- **ALB Metrics** : Request Count, Target Response Time

---

## 🔧 Infrastructure as Code

### **Terraform**

```
Structure :
terraform/
├── versions.tf          # Providers
├── variables.tf         # Variables
├── terraform.tfvars     # Valeurs
├── main.tf              # Module EKS
├── vpc.tf               # Réseau
├── security-groups.tf   # Pare-feu
├── rds.tf               # Base données
├── s3.tf                # Stockage
├── ecr.tf               # Registre Docker
├── iam.tf               # Permissions
├── alb-controller.tf    # Load Balancer
├── kubernetes-resources.tf  # K8s objects
└── outputs.tf           # Résultats

Commandes :
- terraform init    # Initialiser
- terraform plan    # Prévisualiser
- terraform apply   # Créer infrastructure
- terraform destroy # Détruire infrastructure
```

---

## 🚀 Déploiement

### **Workflow Complet**

```bash
1. Build images Docker (Backend, Frontend, Worker)
2. Push images vers ECR
3. terraform apply (crée toute l'infrastructure)
4. kubectl apply (déjà fait par Terraform)
5. Initialiser base de données (init-db.js)
6. Tester application via URL ALB
```

---

## 📈 Performance

### **Capacité**

```
Worker Nodes : 2x t3.small (4 vCPU, 4 GB RAM total)
Pods Simultanés : ~8-10 Pods max
Trafic : ~500-1000 requêtes/minute
Base de données : ~50 connexions simultanées

Avec HPA activé :
  Max 5 Nodes → 10 vCPU, 10 GB RAM
  Max 25 Pods
  Trafic : ~3000-5000 requêtes/minute
```

---

## 💰 Coûts Estimés (us-east-1)

```
Composant               Coût/mois (dev)
─────────────────────────────────────
EKS Control Plane       $72
Worker Nodes (2x t3.small)  ~$30
RDS db.t3.micro         $15 (ou Free Tier)
NAT Gateway             ~$32
ALB                     ~$20
S3 (< 5 GB)             ~$0.12
ECR (< 500 MB)          $0
CloudWatch Logs         ~$5
─────────────────────────────────────
TOTAL                   ~$174/mois

Avec terraform destroy quand inutilisé :
  Coût réel : ~$20-30/mois (tests ponctuels)
```

---

## 🎯 Évolutions Futures

### **Partie 6 - CI/CD**
- GitHub Actions pipeline
- Build automatique sur git push
- Déploiement automatique sur EKS

### **Partie 7 - Traitement Asynchrone**
- Queue SQS pour emails
- Activation Worker
- Notifications clients

### **Partie 8 - Monitoring Avancé**
- Prometheus + Grafana
- Alertes CloudWatch
- Dashboards métriques

### **Partie 9 - Sécurité Avancée**
- WAF sur ALB
- Network Policies Kubernetes
- Secrets Manager au lieu de Secrets K8s
- HTTPS avec ACM

---

## 📚 Références

- **AWS EKS** : https://docs.aws.amazon.com/eks/
- **Kubernetes** : https://kubernetes.io/docs/
- **Terraform AWS Provider** : https://registry.terraform.io/providers/hashicorp/aws/
- **AWS Load Balancer Controller** : https://kubernetes-sigs.github.io/aws-load-balancer-controller/

---

**Auteur** : Oumayma El Abdi  
**Date** : Mars 2026  
**Version** : 1.0