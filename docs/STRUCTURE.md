# 🛒 E-Commerce Application


## 🗂️ Structure du Projet
```
ecommerce-pfe/
│
├── 📱 frontend/                 # Application React.js
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   ├── services/
│   │   └── App.js
│   ├── public/
│   ├── package.json
│   └── Dockerfile
│
├── 🔧 backend/                  # API Node.js + Express
│   ├── routes/
│   ├── controllers/
│   ├── models/
│   ├── middleware/
│   ├── server.js
│   ├── init-db.js
│   ├── package.json
│   ├── .env.example
│   └── Dockerfile
│
├── ⚙️ worker/                   # Worker SQS (envoi emails)
│   ├── worker.js
│   ├── package.json
│   └── Dockerfile
│
├── 🏗️ terraform/                # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── vpc/
│       ├── eks/
│       ├── rds/
│       └── s3/
│
├── ☸️ k8s/                       # Manifests Kubernetes
│   ├── frontend/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── backend/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── worker/
│       └── deployment.yaml
│
├── 🔄 .github/workflows/        # CI/CD Pipelines
│   ├── frontend.yml
│   ├── backend.yml
│   └── terraform.yml
│
├── 📚 docs/                     # Documentation
│   ├── architecture.md
│   ├── deployment.md
│   └── api.md
│
├── .gitignore
├── README.md
└── docker-compose.yml           # Développement local
```

---

## 🏗️ Architecture

### Vue d'ensemble
```
┌─────────────┐
│   Client    │
│  (Browser)  │
└──────┬──────┘
       │ HTTPS
       ▼
┌──────────────────────┐
│  Application Load    │
│     Balancer         │
└──────┬───────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│         EKS Cluster                 │
│                                     │
│  ┌──────────┐      ┌─────────────┐ │
│  │ Frontend │      │   Backend   │ │
│  │  Pods    │◄────►│    Pods     │ │
│  │ (React)  │      │  (Node.js)  │ │
│  └──────────┘      └──────┬──────┘ │
│                           │         │
└───────────────────────────┼─────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌──────────────┐   ┌──────────────┐
│   RDS MySQL   │   │  S3 Bucket   │   │  SQS Queue   │
│   Database    │   │   (Images)   │   │   (Jobs)     │
└───────────────┘   └──────────────┘   └──────┬───────┘
                                              │
                                              ▼
                                    ┌──────────────────┐
                                    │  Worker Pods     │
                                    │  (Email sender)  │
                                    └──────────────────┘
```

---

## 🔵 Services AWS Utilisés

| Service | Description | Utilisation |
|---------|-------------|-------------|
| **VPC** | Réseau privé isolé | Isolation et sécurité réseau |
| **EKS** | Kubernetes managé | Orchestration des conteneurs |
| **RDS** | Base de données MySQL | Stockage des données |
| **S3** | Stockage objets | Images produits + Terraform state |
| **ECR** | Registry Docker | Images des conteneurs |
| **SQS** | File d'attente | Jobs asynchrones (emails) |
| **IAM** | Gestion des accès | Permissions et rôles |
| **CloudWatch** | Monitoring | Logs et métriques |
| **Secrets Manager** | Gestion secrets | Mots de passe et clés API |
| **NAT Gateway** | Accès Internet | Sortie Internet pour subnets privés |
| **ALB** | Load Balancer | Distribution du trafic |

---

## 🚀 Technologies Utilisées

### Frontend
- ⚛️ **React.js** - Framework UI
- 🎨 **TailwindCSS** / **Material-UI** - Styling
- 🔄 **Axios** - HTTP Client
- 🗂️ **React Router** - Navigation

### Backend
- 🟢 **Node.js** - Runtime JavaScript
- 🚂 **Express.js** - Framework web
- 🗄️ **MySQL** - Base de données
- 🔐 **JWT** - Authentication
- ✅ **Joi** - Validation

### DevOps
- 🐳 **Docker** - Containerisation
- ☸️ **Kubernetes** - Orchestration
- 🏗️ **Terraform** - Infrastructure as Code
- 🔄 **GitHub Actions** - CI/CD

### AWS Services
- ☁️ Amazon EKS, RDS, S3, SQS, ECR, CloudWatch


# 🔵 POURQUOI Chaque Service AWS dans le Projet ?

## 📚 Guide Complet pour Comprendre l'Architecture

---

## 1️⃣ **VPC (Virtual Private Cloud)**

### 🤔 C'est quoi ?
Un réseau privé isolé dans AWS où vous déployez vos ressources.

### 💡 Pourquoi dans notre projet ?
- **Sécurité** : Isoler votre application du reste d'Internet
- **Contrôle** : Vous définissez vos règles réseau
- **Organisation** : Séparer les ressources publiques/privées

### 📊 Dans notre app :
```
VPC (10.0.0.0/16)
├── Subnet Public 1 (10.0.1.0/24)  ← Frontend accessible
├── Subnet Public 2 (10.0.2.0/24)  ← Load Balancer
├── Subnet Privé 1 (10.0.3.0/24)   ← Backend API
└── Subnet Privé 2 (10.0.4.0/24)   ← Base de données RDS
```

---

## 2️⃣ **EKS (Elastic Kubernetes Service)**

### 🤔 C'est quoi ?
Service managé pour Kubernetes (orchestration de conteneurs).

### 💡 Pourquoi dans notre projet ?
- **Auto-scaling** : Ajouter automatiquement des conteneurs si traffic élevé
- **Auto-healing** : Redémarrer automatiquement les conteneurs crashés
- **Rolling updates** : Déployer sans downtime
- **Load balancing** : Distribuer le traffic entre conteneurs

### 📊 Dans notre app :
```
EKS Cluster
├── Frontend Deployment (3 pods)
├── Backend Deployment (5 pods)
└── Worker Deployment (2 pods)
```

Si un pod tombe → Kubernetes le redémarre automatiquement !

### 🎯 Alternative sans EKS :
✅ EC2 avec Docker → Mais VOUS devez gérer scaling, monitoring, restarts
❌ Plus de travail manuel, moins de résilience

---

## 3️⃣ **RDS (Relational Database Service)**

### 🤔 C'est quoi ?
Base de données MySQL managée par AWS.

### 💡 Pourquoi dans notre projet ?
- **Backups automatiques** : AWS sauvegarde tous les jours
- **Multi-AZ** : Réplication automatique si datacenter tombe
- **Scaling** : Augmenter le CPU/RAM facilement
- **Patches** : AWS fait les mises à jour de sécurité
- **Monitoring** : CloudWatch intégré

### 📊 Dans notre app :
Stocke : Users, Products, Orders, Cart

### 🎯 Alternative sans RDS :
✅ MySQL sur EC2 → Mais VOUS devez gérer backups, patches, HA
❌ Plus de risques de perte de données

---

## 4️⃣ **S3 (Simple Storage Service)**

### 🤔 C'est quoi ?
Stockage d'objets (fichiers) illimité.

### 💡 Pourquoi dans notre projet ?
- **Images produits** : Stocker les photos uploadées par admin
- **Terraform state** : Stocker l'état de l'infrastructure
- **Logs** : Archiver les vieux logs (optionnel)
- **Durabilité** : 99.999999999% (11 neufs !)

### 📊 Dans notre app :
```
Bucket: ecommerce-product-images/
├── products/1/laptop.jpg
├── products/2/iphone.jpg
└── products/3/headphones.jpg
```

### 🎯 Alternative sans S3 :
✅ Stocker dans MySQL → ❌ Base de données devient énorme et lente
✅ Stocker sur le serveur → ❌ Si pod redémarre, images perdues !

---

## 5️⃣ **ECR (Elastic Container Registry)**

### 🤔 C'est quoi ?
Registry privé pour stocker vos images Docker.

### 💡 Pourquoi dans notre projet ?
- **Sécurité** : Images privées, pas publiques comme Docker Hub
- **Intégration AWS** : EKS peut pull directement
- **Scanning** : Détection automatique de vulnérabilités
- **Lifecycle policies** : Supprimer les vieilles images

### 📊 Dans notre app :
```
ECR Repositories:
├── ecommerce-frontend:latest
├── ecommerce-backend:v1.2.3
└── ecommerce-worker:v1.0.1
```

### 🎯 Alternative sans ECR :
✅ Docker Hub → Mais images publiques = risque sécurité
✅ Registry privé self-hosted → Plus de maintenance

---

## 6️⃣ **SQS (Simple Queue Service)**

### 🤔 C'est quoi ?
File d'attente de messages (queue).

### 💡 Pourquoi dans notre projet ?
- **Asynchrone** : Ne pas bloquer l'API pendant envoi email
- **Fiabilité** : Si worker tombe, messages restent dans la queue
- **Découplage** : API et Worker indépendants
- **Scaling** : Ajouter plus de workers si beaucoup de messages

### 📊 Dans notre app :
```
Flux :
1. Client passe commande
2. API répond immédiatement "Commande créée"
3. API envoie message à SQS { orderId: 123, userId: 5 }
4. Worker lit le message
5. Worker envoie email de confirmation
```

### 🎯 Alternative sans SQS :
❌ Envoyer email directement dans l'API
- Client attend 5-10 secondes
- Si envoi échoue, commande échoue aussi
- Pas scalable

---

## 7️⃣ **IAM (Identity and Access Management)**

### 🤔 C'est quoi ?
Gestion des permissions AWS (qui peut faire quoi).

### 💡 Pourquoi dans notre projet ?
- **Sécurité** : Principe du moindre privilège
- **Roles** : EKS pods ont accès S3 et SQS
- **Users** : Développeurs, CI/CD
- **Policies** : Permissions granulaires

### 📊 Dans notre app :
```
Roles:
├── EKSWorkerNodeRole → EC2 peut joindre cluster EKS
├── BackendPodRole → Backend peut écrire dans S3 et SQS
├── WorkerPodRole → Worker peut lire SQS
└── TerraformRole → Terraform peut créer ressources
```

### 🎯 Alternative sans IAM :
❌ Utiliser access keys dans le code = DANGER !
- Si code fuité → Hackeur a accès complet
- Pas d'audit trail

---

## 8️⃣ **CloudWatch (Monitoring & Logs)**

### 🤔 C'est quoi ?
Service de monitoring et centralisation des logs.

### 💡 Pourquoi dans notre projet ?
- **Logs** : Voir tous les logs en un endroit
- **Métriques** : CPU, RAM, nombre de requêtes
- **Alertes** : Email si CPU > 80%
- **Dashboards** : Visualisation graphique

### 📊 Dans notre app :
```
CloudWatch Logs:
├── /aws/eks/ecommerce/frontend
├── /aws/eks/ecommerce/backend
├── /aws/eks/ecommerce/worker
└── /aws/rds/ecommerce-db

CloudWatch Metrics:
├── CPU Utilization
├── Memory Usage
├── HTTP Requests/minute
└── SQS Messages in Queue
```

### 🎯 Alternative sans CloudWatch :
❌ SSH dans chaque pod pour voir les logs
- Impossible si 10+ pods
- Logs perdus si pod redémarre

---

## 9️⃣ **Secrets Manager**

### 🤔 C'est quoi ?
Stockage sécurisé de secrets (mots de passe, clés API).

### 💡 Pourquoi dans notre projet ?
- **Sécurité** : Mots de passe chiffrés
- **Rotation** : Changer automatiquement les mots de passe
- **Audit** : Qui a accédé à quel secret
- **Versioning** : Historique des changements

### 📊 Dans notre app :
```
Secrets:
├── ecommerce/db/password → "MySuperPassword123!"
├── ecommerce/jwt/secret → "jwt-secret-key-32-chars"
└── ecommerce/sendgrid/key → "SG.xxxxx"
```

### 🎯 Alternative sans Secrets Manager :
❌ Mots de passe dans .env dans le code
- Si code fuité sur GitHub → Game over
- Difficile de changer

---

## 🔟 **NAT Gateway**

### 🤔 C'est quoi ?
Passerelle permettant aux ressources privées d'accéder à Internet.

### 💡 Pourquoi dans notre projet ?
- **Updates** : Pods privés peuvent télécharger packages npm
- **APIs externes** : Backend peut appeler APIs tierces
- **Sécurité** : Traffic sortant seulement, pas entrant

### 📊 Dans notre app :
```
Subnet Privé (Backend)
    ↓
NAT Gateway (Subnet Public)
    ↓
Internet Gateway
    ↓
Internet (npm registry, APIs)
```

### 🎯 Alternative sans NAT Gateway :
❌ Pods dans subnet public → Danger !
✅ Aucune connexion Internet → Impossible de faire npm install

---

## 1️⃣1️⃣ **Load Balancer (ALB)**

### 🤔 C'est quoi ?
Répartit le traffic entre plusieurs cibles.

### 💡 Pourquoi dans notre projet ?
- **High Availability** : Si un pod tombe, autres répondent
- **SSL/TLS** : Terminer HTTPS au Load Balancer
- **Health checks** : Retirer automatiquement pods malades
- **Scaling** : Distribuer traffic entre 1, 10 ou 100 pods

### 📊 Dans notre app :
```
Client HTTPS
    ↓
ALB (Port 443)
    ↓ ↓ ↓
Frontend Pod 1, Pod 2, Pod 3
```

### 🎯 Alternative sans ALB :
❌ 1 seul pod → Si tombe, site down
❌ IP publique par pod → Compliqué pour DNS

---

## 📊 **RÉSUMÉ : Flux Complet**

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ HTTPS
┌──────▼────────────────┐
│   Load Balancer       │
└──────┬────────────────┘
       │
┌──────▼──────────────────────────┐
│        EKS Cluster              │
│  ┌──────────┐  ┌─────────────┐ │
│  │ Frontend │  │   Backend   │ │
│  │  (React) │◄─┤  (Node.js)  │ │
│  └──────────┘  └──┬────────┬─┘ │
│                   │        │    │
└───────────────────┼────────┼────┘
                    │        │
        ┌───────────▼───┐ ┌──▼───────────┐
        │   RDS MySQL   │ │   S3 Images  │
        └───────────────┘ └──────────────┘
                    │
            ┌───────▼─────────┐
            │   SQS Queue     │
            └───────┬─────────┘
                    │
            ┌───────▼─────────┐
            │  Worker (Email) │
            └─────────────────┘
```

---

## 🎯 **Pourquoi CETTE Architecture ?**

### ✅ **Avantages**
1. **Haute Disponibilité** : Si un composant tombe, autres continuent
2. **Scalabilité** : Ajouter des ressources facilement
3. **Sécurité** : Isolation réseau, secrets chiffrés
4. **Observabilité** : Logs et métriques centralisés
5. **Coût optimisé** : Payer seulement ce qu'on utilise
6. **Automatisation** : Infrastructure as Code avec Terraform

### ❌ **Inconvénients**
1. Plus complexe qu'un simple serveur
2. Courbe d'apprentissage AWS
3. Coûts AWS à surveiller

---



