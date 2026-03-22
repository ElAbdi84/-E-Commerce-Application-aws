# 🛒 E-Commerce Platform - Projet PFE DevOps & Cloud AWS

[![AWS](https://img.shields.io/badge/AWS-EKS%20%7C%20RDS%20%7C%20S3-orange)](https://aws.amazon.com)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.31-blue)](https://kubernetes.io)
[![Terraform](https://img.shields.io/badge/Terraform-1.5-purple)](https://terraform.io)
[![Node.js](https://img.shields.io/badge/Node.js-18-green)](https://nodejs.org)
[![React](https://img.shields.io/badge/React-18-blue)](https://reactjs.org)

**Plateforme e-commerce complète déployée sur AWS avec architecture cloud-native et pratiques DevOps modernes.**

---

## 📑 Table des Matières

- [Vue d'Ensemble](#vue-densemble)
- [Architecture](#architecture)
- [Technologies Utilisées](#technologies-utilisées)
- [Fonctionnalités](#fonctionnalités)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Utilisation](#utilisation)
- [Monitoring](#monitoring)
- [Sécurité](#sécurité)
- [Coûts AWS](#coûts-aws)
- [Maintenance](#maintenance)
- [Auteur](#auteur)

---

## 🎯 Vue d'Ensemble

Cette plateforme e-commerce est un projet de fin d'études démontrant l'implémentation complète d'une architecture cloud-native sur AWS avec :

- **Infrastructure as Code** (Terraform)
- **Orchestration Kubernetes** (Amazon EKS)
- **CI/CD automatisé** (GitHub Actions)
- **Messaging asynchrone** (AWS SQS)
- **Monitoring centralisé** (CloudWatch + FluentBit)
- **Auto-scaling** (Horizontal Pod Autoscaler)
- **Haute disponibilité** (Multi-AZ, Load Balancing)

### Cas d'Usage

- Vente en ligne de produits
- Gestion des commandes et paiements
- Notifications par email (AWS SES)
- Tableau de bord admin
- Traitement asynchrone des commandes

---

## 🏗️ Architecture

### Architecture Globale

```
┌─────────────────────────────────────────────────────────────────┐
│                          INTERNET                                │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │   Route 53     │ (DNS - Optionnel)
                    └────────┬───────┘
                             │
                             ▼
┌────────────────────────────────────────────────────────────────┐
│                    AWS CLOUD (us-east-1)                        │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐│
│  │                 VPC (10.0.0.0/16)                           ││
│  │                                                              ││
│  │  ┌──────────────────────────────────────────────────────┐  ││
│  │  │          PUBLIC SUBNETS (Multi-AZ)                    │  ││
│  │  │                                                        │  ││
│  │  │  ┌──────────────────────────────────────────────┐    │  ││
│  │  │  │   Application Load Balancer (ALB)            │    │  ││
│  │  │  │   - SSL/TLS Termination                      │    │  ││
│  │  │  │   - Health Checks                            │    │  ││
│  │  │  └──────────────┬───────────────────────────────┘    │  ││
│  │  │                 │                                      │  ││
│  │  │                 ▼                                      │  ││
│  │  │  ┌──────────────────────────────────────────────┐    │  ││
│  │  │  │   Amazon EKS Cluster (Kubernetes 1.31)       │    │  ││
│  │  │  │                                               │    │  ││
│  │  │  │  ┌────────────┐  ┌────────────┐             │    │  ││
│  │  │  │  │  Backend   │  │  Backend   │ (Pods)      │    │  ││
│  │  │  │  │  Pod 1     │  │  Pod 2     │             │    │  ││
│  │  │  │  │  Node.js   │  │  Node.js   │             │    │  ││
│  │  │  │  └──────┬─────┘  └──────┬─────┘             │    │  ││
│  │  │  │         │                │                    │    │  ││
│  │  │  │  ┌────────────┐  ┌────────────┐             │    │  ││
│  │  │  │  │ Frontend   │  │ Frontend   │ (Pods)      │    │  ││
│  │  │  │  │  Pod 1     │  │  Pod 2     │             │    │  ││
│  │  │  │  │  React     │  │  React     │             │    │  ││
│  │  │  │  └────────────┘  └────────────┘             │    │  ││
│  │  │  │                                               │    │  ││
│  │  │  │  ┌────────────┐                              │    │  ││
│  │  │  │  │  Worker    │ (Pod)                        │    │  ││
│  │  │  │  │  SQS       │                              │    │  ││
│  │  │  │  │  Consumer  │                              │    │  ││
│  │  │  │  └──────┬─────┘                              │    │  ││
│  │  │  │         │                                     │    │  ││
│  │  │  │  ┌──────┴─────┐                              │    │  ││
│  │  │  │  │ FluentBit  │ (DaemonSet)                 │    │  ││
│  │  │  │  │ Logs Agent │                              │    │  ││
│  │  │  │  └────────────┘                              │    │  ││
│  │  │  └───────────────────────────────────────────────┘    │  ││
│  │  └──────────────────────────────────────────────────────┘  ││
│  │                                                              ││
│  │  ┌──────────────────────────────────────────────────────┐  ││
│  │  │          AWS MANAGED SERVICES                         │  ││
│  │  │                                                        │  ││
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐     │  ││
│  │  │  │ RDS MySQL  │  │  S3 Bucket │  │ SQS Queue  │     │  ││
│  │  │  │ (Database) │  │  (Images)  │  │ + DLQ      │     │  ││
│  │  │  └────────────┘  └────────────┘  └────────────┘     │  ││
│  │  │                                                        │  ││
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐     │  ││
│  │  │  │ CloudWatch │  │    SES     │  │    ECR     │     │  ││
│  │  │  │  (Logs +   │  │  (Emails)  │  │  (Images)  │     │  ││
│  │  │  │  Metrics)  │  │            │  │            │     │  ││
│  │  │  └────────────┘  └────────────┘  └────────────┘     │  ││
│  │  └──────────────────────────────────────────────────────┘  ││
│  └──────────────────────────────────────────────────────────┘ ││
└────────────────────────────────────────────────────────────────┘
```

### Architecture Applicative

```
┌─────────────┐
│   Client    │
│  (Browser)  │
└──────┬──────┘
       │ HTTP
       ▼
┌─────────────┐
│     ALB     │ (Load Balancer)
└──────┬──────┘
       │
       ├──────────────┬──────────────┐
       │              │              │
       ▼              ▼              ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│  Frontend   │ │  Backend    │ │  Backend    │
│   (React)   │ │  (Node.js)  │ │  (Node.js)  │
└─────────────┘ └──────┬──────┘ └──────┬──────┘
                       │                │
                       ├────────────────┤
                       │                │
                       ▼                ▼
                ┌─────────────┐  ┌─────────────┐
                │ RDS MySQL   │  │  SQS Queue  │
                │  (Database) │  │  (Messages) │
                └─────────────┘  └──────┬──────┘
                                        │
                                        ▼
                                 ┌─────────────┐
                                 │   Worker    │
                                 │ (SQS        │
                                 │  Consumer)  │
                                 └──────┬──────┘
                                        │
                                        ▼
                                 ┌─────────────┐
                                 │  AWS SES    │
                                 │  (Emails)   │
                                 └─────────────┘
```

### Flux de Données

**1. Création de Commande**
```
User → Frontend → Backend → RDS (save order)
                          ↓
                    SQS Queue (send message)
                          ↓
                       Worker (poll queue)
                          ↓
                    AWS SES (send email)
                          ↓
                   RDS (save notification)
```

**2. Logs et Monitoring**
```
All Pods → FluentBit → CloudWatch Logs
         ↓
    CloudWatch Metrics → Dashboard + Alarms
```

---

## 🛠️ Technologies Utilisées

### Frontend
- **React 18** - Framework UI
- **React Router** - Navigation
- **Axios** - HTTP client
- **Tailwind CSS** - Styling (via classes utilitaires)

### Backend
- **Node.js 18** - Runtime JavaScript
- **Express.js** - Framework web
- **MySQL2** - Driver MySQL
- **bcrypt** - Hashing passwords
- **jsonwebtoken** - Authentification JWT
- **AWS SDK** - Intégration AWS (S3, SQS, SES)
- **multer** - Upload fichiers

### Worker
- **Node.js 18** - Runtime
- **AWS SDK** - SQS Consumer
- **MySQL2** - Database access

### Infrastructure
- **AWS EKS** - Kubernetes managé
- **Amazon RDS** - Base de données MySQL
- **Amazon S3** - Stockage objets (images)
- **Amazon SQS** - Queue de messages
- **AWS SES** - Service email
- **Amazon ECR** - Registre Docker
- **CloudWatch** - Monitoring et logs
- **Application Load Balancer** - Load balancing

### DevOps
- **Terraform 1.5+** - Infrastructure as Code
- **Docker** - Containerisation
- **Kubernetes 1.31** - Orchestration
- **GitHub Actions** - CI/CD
- **FluentBit** - Collecte de logs
- **Helm** - Package manager Kubernetes

---

## ✨ Fonctionnalités

### Utilisateur
- ✅ Inscription et connexion (JWT)
- ✅ Navigation catalogue produits
- ✅ Filtrage par catégorie
- ✅ Recherche produits
- ✅ Gestion panier
- ✅ Passage de commande
- ✅ Historique commandes
- ✅ Email de confirmation

### Admin
- ✅ Ajout/Modification/Suppression produits
- ✅ Upload images vers S3
- ✅ Gestion catégories
- ✅ Vue commandes
- ✅ Gestion stock

### Technique
- ✅ Auto-scaling pods (HPA)
- ✅ Health checks
- ✅ Retry automatique (SQS)
- ✅ Dead Letter Queue
- ✅ Logs centralisés
- ✅ Monitoring temps réel
- ✅ Alertes CloudWatch
- ✅ Haute disponibilité (Multi-AZ)

---

## 📋 Prérequis

### Logiciels Requis
```bash
- AWS CLI (v2.x)
- Terraform (>= 1.5.0)
- kubectl (>= 1.28)
- Docker (>= 20.x)
- Node.js (>= 18.x)
- Git
```

### Compte AWS
- Compte AWS actif
- IAM User avec permissions :
  - `AdministratorAccess` (ou permissions granulaires)
- AWS Access Key ID et Secret Access Key

### Autres
- Domaine (optionnel pour DNS)
- Email vérifié AWS SES (pour envoi emails)

---

## 🚀 Installation

### 1. Cloner le Projet

```bash
git clone https://github.com/votre-username/ecommerce-pfe.git
cd ecommerce-pfe
```

### 2. Configurer AWS CLI

```bash
aws configure
# AWS Access Key ID: YOUR_KEY
# AWS Secret Access Key: YOUR_SECRET
# Default region: us-east-1
# Default output format: json
```

### 3. Configurer Variables Terraform

```bash
# Copier fichier d'exemple
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Éditer avec vos valeurs
nano terraform/terraform.tfvars
```

**Exemple `terraform.tfvars` :**
```hcl
project_name          = "ecommerce-pfe-elabdi"
environment           = "dev"
aws_region            = "us-east-1"
db_username           = "admin"
db_password           = "YourSecurePassword123!"
db_name               = "ecommerce"
jwt_secret            = "your-jwt-secret-key-here"
aws_access_key_id     = "YOUR_AWS_ACCESS_KEY"
aws_secret_access_key = "YOUR_AWS_SECRET_KEY"
```

### 4. Déployer l'Infrastructure

```bash
# Rendre script exécutable
chmod +x deploy-infra.sh

# Déployer TOUT automatiquement
./deploy-infra.sh

# Taper 'yes' pour confirmer
```

**Durée : 15-20 minutes**

**Le script va :**
1. Créer infrastructure AWS (VPC, EKS, RDS, S3, SQS)
2. Configurer Kubernetes
3. Builder et pusher images Docker
4. Déployer applications
5. Initialiser base de données
6. Créer dashboard CloudWatch

### 5. Récupérer l'URL

```bash
# URL affichée à la fin du script
# Exemple : http://k8s-default-ecommerc-xxx.elb.amazonaws.com
```

---

## 💻 Utilisation

### Accéder à l'Application

```
URL: http://[ALB_URL]
```

### Comptes par Défaut

**Admin :**
```
Email: admin@ecommerce.com
Password: admin123
```

**Client Test :**
```
Email: john@example.com
Password: user123
```

### Commandes Utiles

**Voir les pods :**
```bash
kubectl get pods
```

**Logs Backend :**
```bash
kubectl logs -f deployment/backend-deployment
```

**Logs Worker :**
```bash
kubectl logs -f deployment/worker-deployment
```

**Logs FluentBit :**
```bash
kubectl logs -n logging -l app=fluent-bit
```

**Dashboard CloudWatch :**
```bash
# URL affichée après déploiement
# Ou via AWS Console → CloudWatch → Dashboards
```

**Stats SQS :**
```bash
curl http://[ALB_URL]/api/sqs/stats
```

---

## 📊 Monitoring

### CloudWatch Dashboard

**Widgets disponibles :**
- ALB Traffic & Latency
- HTTP Status Codes (2xx, 4xx, 5xx)
- SQS Messages Activity
- RDS Metrics (CPU, Connections)
- Backend Error Logs
- Worker Activity Logs

### CloudWatch Alarms

**Alarmes configurées :**
- Backend CPU > 80%
- Worker Memory > 85%
- ALB 5xx Errors > 10

### Logs Centralisés

**Log Groups :**
- `/aws/eks/[cluster]/backend`
- `/aws/eks/[cluster]/frontend`
- `/aws/eks/[cluster]/worker`

**Requête Logs Insights (erreurs) :**
```sql
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 50
```

---

## 🔒 Sécurité

### Secrets Management

**Kubernetes Secrets utilisés :**
- `db-credentials` - Identifiants base de données
- `jwt-secret` - Clé JWT
- `aws-credentials` - Credentials AWS

**Pas de secrets en clair dans :**
- Code source ✅
- Images Docker ✅
- Variables d'environnement publiques ✅

### IAM Roles

**Principe du moindre privilège :**
- FluentBit : Accès CloudWatch Logs uniquement
- Worker : Accès SQS + SES uniquement
- Backend : Accès S3 + SQS uniquement

### Network Security

- VPC isolé (10.0.0.0/16)
- Security Groups restrictifs
- Pods non exposés publiquement
- Accès uniquement via ALB

---

## 💰 Coûts AWS

### Estimation Mensuelle

| Service | Type | Coût/mois |
|---------|------|-----------|
| EKS Cluster | Fixe | $73 |
| EC2 (2x t3.medium) | Compute | $60 |
| RDS (db.t3.micro) | Database | $15 |
| ALB | Load Balancer | $16 |
| S3 | Storage | $2 |
| CloudWatch | Monitoring | $3 |
| SQS | Messaging | $1 |
| **TOTAL** | | **~$170/mois** |

**Avec Free Tier (12 mois) : ~$70-90/mois**

### Optimisations Possibles

- ✅ Arrêter RDS la nuit (-$10/mois)
- ✅ Utiliser Spot Instances (-$30/mois)
- ✅ 1 seul node EKS dev (-$30/mois)
- ✅ Supprimer NAT Gateway (-$32/mois)

---

## 🧹 Maintenance

### Destroy Infrastructure

```bash
# Script automatique
./destroy-infra.sh

# Taper 'DESTROY' pour confirmer
```

**Supprime TOUT :**
- Cluster EKS
- RDS Database
- VPC + Subnets
- S3 Bucket
- SQS Queue
- CloudWatch Logs
- Dashboard
- IAM Roles

**Durée : 10-15 minutes**

### Backup Base de Données

```bash
# Backup manuel
kubectl exec -it deployment/backend-deployment -- \
  mysqldump -h [RDS_ENDPOINT] -u admin -p ecommerce > backup.sql
```

### Mise à Jour Application

```bash
# 1. Modifier code
# 2. Push vers GitHub
# 3. GitHub Actions rebuild et redéploie automatiquement

# OU manuellement :
cd backend
docker build -t [ECR_REGISTRY]/ecommerce-backend:latest .
docker push [ECR_REGISTRY]/ecommerce-backend:latest
kubectl rollout restart deployment/backend-deployment
```

---

## 📂 Structure du Projet

```
ecommerce-pfe/
├── backend/                # API Node.js
│   ├── server.js
│   ├── init-db.js
│   ├── services/
│   │   └── sqsService.js
│   ├── Dockerfile
│   └── package.json
├── frontend/              # Application React
│   ├── src/
│   ├── public/
│   ├── Dockerfile
│   └── package.json
├── worker/                # SQS Consumer
│   ├── index.js
│   ├── Dockerfile
│   └── package.json
├── terraform/             # Infrastructure AWS
│   ├── main.tf
│   ├── vpc.tf
│   ├── eks.tf
│   ├── rds.tf
│   ├── s3.tf
│   ├── sqs.tf
│   ├── cloudwatch.tf
│   └── variables.tf
├── terraform-k8s/         # Ressources Kubernetes
│   ├── kubernetes-resources.tf
│   ├── fluentbit.tf
│   └── data.tf
├── .github/workflows/     # CI/CD
│   └── deploy.yml
├── deploy-infra.sh        # Script déploiement
├── destroy-infra.sh       # Script suppression
└── README.md
```

---

## 👤 Auteur

**Oumayma El Abdi**

- 🎓 Étudiante en Génie Informatique
- 🏫 Université Mohamed V
- 📧 Email: o.elabdi@edu.umi.ac.ma
- 🔗 LinkedIn: [Votre LinkedIn]
- 💻 GitHub: [Votre GitHub]

**Projet de Fin d'Études**
- Spécialité : DevOps & Cloud Computing
- Année : 2025-2026
- Encadrant : [Nom Encadrant]

---

## 📄 Licence

Ce projet est réalisé dans le cadre d'un projet académique.

---

## 🙏 Remerciements

- AWS pour la documentation et les Free Tier
- Communauté Terraform et Kubernetes
- Professeurs et encadrants UMI

---

## 📚 Documentation Complémentaire

- [Guide Terraform](./docs/terraform-guide.md)
- [Guide Kubernetes](./docs/kubernetes-guide.md)
- [API Documentation](./docs/api-docs.md)
- [Troubleshooting](./docs/troubleshooting.md)

---

**⭐ Si ce projet vous a aidé, n'hésitez pas à le partager !**