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
🔐 Security Groups
┌─────────────────────────────────────────────────────────────┐
│                    Security Groups                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. SG-ALB (Application Load Balancer)                      │
│     ├─ IN : 80/443 from 0.0.0.0/0                           │
│     └─ OUT: All traffic                                     │
│                                                             │
│  2. SG-Frontend (React.js Pods)                             │
│     ├─ IN : 3000 from SG-ALB                                │
│     └─ OUT: All traffic                                     │
│                                                             │
│  3. SG-Backend (Node.js Pods)                               │
│     ├─ IN : 5000 from SG-Frontend                           │
│     └─ OUT: 3306 to SG-RDS, 443 to Internet (AWS APIs)      │
│                                                             │
│  4. SG-RDS (MySQL Database)                                 │
│     ├─ IN : 3306 from SG-Backend only                       │
│     └─ OUT: All traffic                                     │
│                                                             │
│  5. SG-EKS-Control-Plane                                    │
│     ├─ IN : 443 from SG-EKS-Nodes                           │
│     └─ OUT: 1024-65535 to SG-EKS-Nodes                      │
│                                                             │
│  6. SG-EKS-Nodes (Worker Nodes)                             │
│     ├─ IN : All from SG-EKS-Nodes (self)                    │
│     ├─ IN : 1024-65535 from SG-EKS-Control                  │
│     └─ OUT: All traffic                                     │
└─────────────────────────────────────────────────────────────┘

🔐 Différence : SG-EKS-Control-Plane vs SG-EKS-Nodes
SG-EKS-Control-Plane  → Protège le CERVEAU d'EKS (géré par AWS)
SG-EKS-Nodes          → Protège les MACHINES qui exécutent vos apps
┌─────────────────────────────────────────────────────────────┐
│                    CLUSTER EKS COMPLET                      │
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │         CONTROL PLANE (Géré par AWS)               │   │
│  │         Security Group: SG-EKS-Control-Plane       │   │
│  │                                                    │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐       │   │
│  │  │ API      │  │ etcd     │  │Scheduler │       │   │
│  │  │ Server   │  │(Database)│  │          │       │   │
│  │  └──────────┘  └──────────┘  └──────────┘       │   │
│  │                                                    │   │
│  │  VOUS ne voyez PAS ces machines                   │   │
│  │  AWS les gère pour vous                           │   │
│  └────────────────────────────────────────────────────┘   │
│                          ↕                                  │
│                   Communication                             │
│                   sécurisée                                 │
│                          ↕                                  │
│  ┌────────────────────────────────────────────────────┐   │
│  │         DATA PLANE (Vos Worker Nodes)              │   │
│  │         Security Group: SG-EKS-Nodes               │   │
│  │                                                    │   │
│  │  ┌─────────────────┐    ┌─────────────────┐      │   │
│  │  │  Node 1 (EC2)   │    │  Node 2 (EC2)   │      │   │
│  │  │  IP: 10.0.3.45  │    │  IP: 10.0.4.78  │      │   │
│  │  │                 │    │                 │      │   │
│  │  │  ┌──────────┐   │    │  ┌──────────┐   │      │   │
│  │  │  │Pod       │   │    │  │Pod       │   │      │   │
│  │  │  │Backend   │   │    │  │Frontend  │   │      │   │
│  │  │  └──────────┘   │    │  └──────────┘   │      │   │
│  │  └─────────────────┘    └─────────────────┘      │   │
│  │                                                    │   │
│  │  VOUS gérez ces machines EC2                      │   │
│  └────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
Protège le Control Plane en autorisant SEULEMENT :
  ✅ Les Worker Nodes à communiquer avec lui
  ❌ Bloque tout le reste

## 2️⃣ **EKS (Elastic Kubernetes Service)**

### 🤔 C'est quoi ?
Service managé pour Kubernetes (orchestration de conteneurs).
C'est un service managé par AWS qui vous permet d'utiliser Kubernetes sans gérer toute la complexité technique.

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
┌────────────────────────────────────────────────┐
│              CLUSTER EKS                       │  ← Le tout
│  (Ensemble de serveurs gérés par Kubernetes)   │
│                                                │
│  ┌──────────────────────────────────────────┐  │
│  │         NODE 1 (= EC2 t3.medium)         │  │  ← Un serveur
│  │         IP: 10.0.3.45                    │  │
│  │         CPU: 2 vCPU                      │  │
│  │         RAM: 4 GB                        │  │
│  │                                          │  │
│  │  ┌─────────────┐  ┌─────────────┐      │ │
│  │  │  Pod 1      │  │  Pod 2      │      │ │  ← Les applications
│  │  │  Backend    │  │  Frontend   │      │ │
│  │  │  (Container)│  │  (Container)│      │ │
│  │  └─────────────┘  └─────────────┘      │ │
│  └──────────────────────────────────────────┘ │
│                                               │
│  ┌──────────────────────────────────────────┐ │
│  │         NODE 2 (= EC2 t3.medium)         │ │  ← Un autre serveur
│  │         IP: 10.0.4.78                    │ │
│  │         CPU: 2 vCPU                      │ │
│  │         RAM: 4 GB                        │ │
│  │                                          │ │
│  │  ┌─────────────┐  ┌─────────────┐      │ │
│  │  │  Pod 3      │  │  Pod 4      │      │ │
│  │  │  Backend    │  │  Worker     │      │ │
│  │  │  (Container)│  │  (Container)│      │ │
│  │  └─────────────┘  └─────────────┘      │ │
│  └──────────────────────────────────────────┘ │
└────────────────────────────────────────────────┘
Cluster (Ensemble)
  ↓
Node (Serveur = Machine = EC2)
  ↓
Pod (Conteneur applicatif)
  ↓
Container (Image Docker qui tourne)

Si un pod tombe → Kubernetes le redémarre automatiquement !

### 🎯 Alternative sans EKS :
✅ EC2 avec Docker → Mais VOUS devez gérer scaling, monitoring, restarts
❌ Plus de travail manuel, moins de résilience
### 🔄 Communication entre Control Plane et Nodes
┌──────────────────────────────────────────────────────────┐
│                  Communication EKS                       │
└──────────────────────────────────────────────────────────┘

1. Node → Control Plane (Port 443)
   ┌─────────────┐         ┌──────────────────┐
   │ Worker Node │  443    │  Control Plane   │
   │ (kubelet)   ├────────→│  (API Server)    │
   └─────────────┘         └──────────────────┘
   
   Exemples :
   - "Je suis en vie" (heartbeat)
   - "J'ai démarré le Pod Backend"
   - "Pod Frontend a crashé"
   - "Mes métriques : CPU 45%, RAM 2GB"

2. Control Plane → Node (Ports 1024-65535)
   ┌──────────────────┐         ┌─────────────┐
   │  Control Plane   │ 10250   │ Worker Node │
   │  (Scheduler)     ├────────→│  (kubelet)  │
   └──────────────────┘         └─────────────┘
   
   Exemples :
   - "Lance ce Pod Backend"
   - "Supprime ce Pod Frontend"
   - "Redémarre ce Pod Worker"
   - "Donne-moi tes logs"

3. Node ↔ Node (All Traffic)
   ┌─────────────┐         ┌─────────────┐
   │  Node 1     │  3000   │  Node 2     │
   │  (Backend)  ├────────→│  (Frontend) │
   └─────────────┘         └─────────────┘
   
   Exemples :
   - Pod Backend → Pod Frontend (port 3000)
   - Pod Frontend → Pod Backend (port 5000)
   - Networking interne Kubernetes


---
### 🎓 Pour Votre Soutenance
Question Attendue :
"Expliquez la différence entre SG-EKS-Control-Plane et SG-EKS-Nodes"
✅ Réponse Modèle :
"Dans EKS, il y a 2 parties distinctes :

1. Le Control Plane (géré par AWS) :
   C'est le cerveau qui contrôle le cluster. Il contient l'API Server,
   etcd (la base de données), et le Scheduler. AWS le gère entièrement.
   
   SG-EKS-Control-Plane protège cette partie en autorisant UNIQUEMENT
   les Worker Nodes à communiquer avec lui sur le port 443.

2. Les Worker Nodes (mes EC2) :
   Ce sont les machines qui exécutent réellement mes applications
   (les Pods Backend, Frontend, Worker).
   
   SG-EKS-Nodes protège ces machines en autorisant :
   - La communication entre les Nodes (pour que les Pods se parlent)
   - La communication avec le Control Plane (pour recevoir des ordres)
   - L'accès Internet (pour pull des images Docker depuis ECR)

Cette séparation renforce la sécurité : même si un Worker Node
est compromis, il ne peut pas accéder directement au Control Plane."

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
🔐 1. SECRETS (k8s/secrets/)
C'est Quoi ?
Les Secrets sont des objets Kubernetes qui stockent des informations sensibles de manière sécurisée.
Secrets:
├── db-credentials.yaml: Stocker les informations de connexion à la base de données RDS.
     ❌ SANS Secret :
   Le mot de passe serait en dur dans le code :
   const password = "Ecommerce2025!"; // DANGER !
   → Visible dans Git
   → Visible par tout le monde
   → Impossible à changer sans recompiler

✅ AVEC Secret :
   Le Pod lit le mot de passe depuis le Secret :
   process.env.DB_PASSWORD
   → Pas dans Git
   → Changeable sans redéployer
   → Encodé en base64 dans Kubernetes


├── jwt-secret.yaml: Stocker la clé secrète pour signer les tokens JWT (authentification).
    JWT = JSON Web Token pour l'authentification

Quand un utilisateur se connecte :
1. Backend vérifie email + password
2. Si OK, Backend crée un JWT signé avec JWT_SECRET
3. Client stocke le JWT
4. Client envoie le JWT à chaque requête
5. Backend vérifie la signature avec JWT_SECRET

Si quelqu'un connaît JWT_SECRET :
  → Il peut créer des faux tokens
  → Il peut se faire passer pour n'importe qui
  → GRAVE PROBLÈME DE SÉCURITÉ !

Donc : JWT_SECRET doit rester SECRET !



└── aws-credentials.yaml:  Stocker les credentials AWS pour accéder à S3 (upload d'images).
   
     Le Backend doit uploader des images produits sur S3.

Pour ça, il a besoin de credentials AWS.

❌ SANS Secret :
   const accessKey = "AKIAXXXXX"; // DANGER !
   → Si quelqu'un vole ces credentials :
     - Il peut accéder à TOUT votre compte AWS
     - Il peut supprimer vos données
     - Il peut créer des ressources (coûts !)

✅ AVEC Secret :
   → Credentials stockés de manière sécurisée
   → Injectés dans le Pod au runtime
   → Pas visibles dans le code source
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
## ⚙️ 2. CONFIGMAP (k8s/configmaps/)

'est Quoi ?
Un ConfigMap stocke des configurations NON sensibles que vos applications peuvent lire.
Différence Secret vs ConfigMap
Secret     : Informations SENSIBLES (mots de passe, clés)
ConfigMap  : Informations NON SENSIBLES (URLs, ports, options)

Pourquoi c'est utile ?
Avantages :
  ✅ Centralisation : Toute la config au même endroit
  ✅ Réutilisabilité : Backend, Frontend, Worker utilisent la même config
  ✅ Changement facile : Modifier sans recompiler l'app
  ✅ Environnements : Différente config pour dev/staging/prod

Exemple concret :
  Dev  : S3_BUCKET_NAME = "ecommerce-dev"
  Prod : S3_BUCKET_NAME = "ecommerce-prod"
  
  Même code, juste le ConfigMap change !

## 🚀 3. DEPLOYMENTS (k8s/deployments/)
C'est Quoi ?
Un Deployment décrit COMMENT déployer une application dans Kubernetes.
Analogie Simple
Deployment = Instructions de déploiement

Comme un plan de construction :
  "Je veux 2 maisons identiques (replicas: 2)
   Chaque maison a 2 chambres (CPU/RAM)
   Si une maison brûle, reconstruis-la immédiatement
   Utilise ce modèle (image Docker)"

Kubernetes lit le plan et construit automatiquement.

backend-deployment.yaml
Rôle : Déployer le Backend Node.js avec toutes ses configurations.

Ce que ça fait :
1. Créer 2 Pods Backend identiques
2. Chaque Pod exécute l'image Docker depuis ECR
3. Injecter les variables d'environnement (ConfigMap + Secrets)
4. Limiter les ressources CPU/RAM (pour ne pas surcharger)
5. Si un Pod crash → Kubernetes le recrée automatiquement
6. Si vous faites "kubectl scale" → Kubernetes ajoute/retire des Pods
Pourquoi 2 replicas ?
Haute Disponibilité :
  Si 1 Pod crash → L'autre continue de servir le trafic
  → Zéro downtime !

Load Balancing :
  Les requêtes sont réparties entre les 2 Pods
  → Meilleure performance

frontend-deployment.yaml
Rôle : Déployer le Frontend React (avec Nginx).
Différence avec Backend :
Frontend :
  - Pas de connexion DB (pas besoin de db-credentials)
  - Sert des fichiers statiques (HTML/CSS/JS)
  - Nginx route vers le Backend pour l'API
  - Moins de ressources nécessaires

worker-deployment.yaml
Rôle : Déployer le Worker qui écoute la queue SQS.
Pourquoi 1 seul replica ?
Le Worker traite des messages asynchrones (emails, notifications).

1 Worker suffit pour commencer car :
  - Les messages SQS sont traités un par un
  - Pas besoin de haute dispo immédiate
  - On peut scaler plus tard si besoin (HPA)

En production avec beaucoup de messages :
  → On passerait à 2-3 replicas

## 🔗 4. SERVICES (k8s/services/)
C'est Quoi ?
Un Service est un point d'accès stable pour communiquer avec des Pods.
Analogie Simple
Pods = Téléphones portables (numéros qui changent)
Service = Standard téléphonique d'entreprise (numéro fixe)

Quand vous appelez l'entreprise :
  1. Vous composez le numéro fixe (Service)
  2. Le standard route vers un téléphone disponible (Pod)
  3. Si un téléphone est occupé, ça route vers un autre

Service K8s = Standard téléphonique pour vos Pods

backend-service.yaml
Rôle : Exposer les Pods Backend en interne dans le cluster.
Comment ça marche ?
1. Frontend veut appeler le Backend
2. Frontend fait une requête à : http://backend-service:5000/api/products
3. Kubernetes DNS résout "backend-service" → IP interne du Service
4. Le Service route vers un des 2 Pods Backend (load balancing)
5. Le Pod Backend répond
6. La réponse revient au Frontend

Avantages :
  ✅ URL stable : backend-service (même si les Pods changent)
  ✅ Load balancing : Répartit le trafic entre les 2 Pods
  ✅ Health checks : Kubernetes retire les Pods malades automatiquement
Pourquoi ClusterIP ?
ClusterIP = Accessible SEULEMENT depuis le cluster

Le Backend ne doit PAS être accessible depuis Internet directement.
Seul le Frontend (via Ingress/ALB) doit être accessible publiquement.

Architecture :
  Internet → ALB → Frontend → backend-service → Backend Pods
                                    ↑
                              (interne uniquement)

frontend-service.yaml
Rôle : Exposer les Pods Frontend en interne.

Pourquoi ClusterIP aussi ?
Le Frontend ne sera PAS exposé directement à Internet non plus.

L'ALB Ingress (qu'on va créer) sera le point d'entrée public :
  Internet → ALB Ingress → frontend-service → Frontend Pods

Séparation claire :
  - Ingress = Porte d'entrée publique
  - Services = Communication interne

🎯 POURQUOI Cette Architecture ?
Principe de Séparation des Responsabilités
Secrets       : Informations sensibles (sécurité)
ConfigMaps    : Configuration non sensible (flexibilité)
Deployments   : QUOI déployer (applications)
Services      : COMMENT communiquer (réseau)

Chaque fichier a UNE responsabilité claire.
→ Facile à maintenir
→ Facile à modifier
→ Facile à comprendre
Avantages pour le Jury
1. Sécurité :
   ✅ Secrets séparés du code
   ✅ Pas de credentials dans Git
   ✅ Principe du moindre privilège

2. Scalabilité :
   ✅ Modifier replicas sans toucher au code
   ✅ Ajouter des Pods facilement
   ✅ Load balancing automatique

3. Maintenabilité :
   ✅ Changer une config sans redéployer
   ✅ Architecture déclarative (Infrastructure as Code)
   ✅ Facile à versionner dans Git

4. Best Practices :
   ✅ Suit les recommandations Kubernetes officielles
   ✅ Architecture production-ready
   ✅ Facilite CI/CD (Partie 6)

## 📊 Schéma Récapitulatif
┌─────────────────────────────────────────────────────┐
│                KUBERNETES CLUSTER                   │
│                                                     │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐   │
│  │  Secrets   │  │ ConfigMaps │  │   Etc...   │   │
│  │            │  │            │  │            │   │
│  │ DB creds   │  │ AWS_REGION │  │            │   │
│  │ JWT secret │  │ S3_BUCKET  │  │            │   │
│  └─────┬──────┘  └─────┬──────┘  └────────────┘   │
│        │                │                           │
│        └────────┬───────┘                           │
│                 ↓                                   │
│  ┌──────────────────────────────────────────────┐  │
│  │         DEPLOYMENTS (Applications)           │  │
│  │                                              │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  │  │
│  │  │ Backend  │  │ Frontend │  │  Worker  │  │  │
│  │  │ 2 Pods   │  │ 2 Pods   │  │  1 Pod   │  │  │
│  │  └─────┬────┘  └─────┬────┘  └──────────┘  │  │
│  └────────┼─────────────┼─────────────────────┘  │
│           │             │                         │
│           ↓             ↓                         │
│  ┌──────────────┐  ┌──────────────┐              │
│  │   Service    │  │   Service    │              │
│  │   Backend    │  │   Frontend   │              │
│  │ (ClusterIP)  │  │ (ClusterIP)  │              │
│  └──────────────┘  └──────────────┘              │
│                                                   │
└─────────────────────────────────────────────────────┘

🎓 Pour la Soutenance : Questions/Réponses
Q1: "Pourquoi séparer les Secrets des Deployments ?"
✅ Réponse :
"Pour des raisons de sécurité et de maintenance. Les Secrets 
contiennent des informations sensibles qui ne doivent jamais 
être dans le code source ou dans Git. En les séparant, je peux :

1. Versionner les Deployments dans Git sans risque
2. Changer un mot de passe sans redéployer l'application
3. Respecter le principe du moindre privilège (seuls les Pods 
   autorisés peuvent lire certains Secrets)
4. Faciliter les audits de sécurité"
Q2: "Pourquoi utiliser des Services au lieu d'accéder directement aux Pods ?"
✅ Réponse :
"Les Pods ont des IP dynamiques qui changent à chaque redémarrage.
Les Services fournissent :

1. Une IP et un nom DNS stables (ex: backend-service)
2. Du load balancing automatique entre les replicas
3. Des health checks : seuls les Pods sains reçoivent du trafic
4. Une abstraction qui facilite la communication inter-services

Sans Services, je devrais gérer manuellement les IPs des Pods, 
ce qui serait ingérable."
Q3: "Pourquoi avoir 2 replicas pour Backend et Frontend mais 1 seul pour Worker ?"
✅ Réponse :
"C'est une question de haute disponibilité et de besoin :

Backend et Frontend (2 replicas) :
- Servent des requêtes HTTP en temps réel
- Doivent avoir zéro downtime
- Le trafic doit être load-balancé
- Si un Pod crash, l'autre prend le relais immédiatement

Worker (1 replica) :
- Traite des tâches asynchrones (emails, notifications)
- Un délai de quelques secondes est acceptable
- Les messages SQS sont persistés, pas de perte
- On peut scaler plus tard avec HPA si le volume augmente

C'est une approche coût-efficace tout en garantissant la disponibilité 
des services critiques."


## Question : "Expliquez le rôle de chaque fichier Terraform"
### 1. versions.tf 
"Configure Terraform et les providers (AWS, Kubernetes, Helm). Garantit que tout le monde utilise les mêmes versions pour la reproductibilité."
### 2. variables.tf 
 "Définit tous les paramètres configurables (région, tailles instances, credentials). Rend le code réutilisable pour différents environnements."
### 3. terraform.tfvars 
 "Contient mes valeurs réelles (mots de passe, noms). JAMAIS versionné dans Git pour la sécurité."
### 4. main.tf 
"Point d'entrée principal. Utilise le module EKS officiel qui encapsule les best practices AWS pour créer un cluster production-ready."
### 5. vpc.tf 
"Crée l'architecture réseau multi-AZ : VPC, subnets publics/privés, IGW, NAT Gateway, route tables. Architecture en 3 tiers pour la sécurité."
### 6. security-groups.tf 
 "Définit les pare-feu pour chaque composant. Applique le principe du moindre privilège : RDS n'accepte QUE les connexions depuis EKS."

 ## ARCHITECTURE PARTIE 5 (Terraform + Kubernetes) :

┌─────────────────────────────────────────┐
│  Internet (0.0.0.0/0)                   │
└────────────────┬────────────────────────┘
                 ↓
┌────────────────────────────────────────┐
│  SG-ALB (Ports 80, 443 depuis Internet)│
│  Application Load Balancer             │
└────────────────┬────────────────────────┘
                 ↓
┌────────────────────────────────────────┐
│  SG-EKS-NODES                          │
│  (Ports 80, 5000 depuis ALB)           │
│                                        │
│  ┌─────────────┐  ┌─────────────┐     │
│  │  Node 1     │  │  Node 2     │     │
│  │ ├─Frontend  │  │ ├─Frontend  │     │
│  │ ├─Backend   │  │ └─Backend   │     │
│  │ └─Worker    │  │             │     │
│  └─────────────┘  └─────────────┘     │
└────────────────┬────────────────────────┘
                 ↓
┌────────────────────────────────────────┐
│  SG-RDS (Port 3306 depuis SG-EKS-Nodes)│
│  RDS MySQL                             │
└────────────────────────────────────────┘

= 3 Security Groups seulement ! ✅

Question : "Si Backend et Frontend sont sur le même Node, comment le Backend reste-t-il privé ?"
✅ Réponse Modèle :
"Bien que Backend et Frontend PUISSENT tourner sur le même Worker Node, ils restent isolés car :
1. Chaque application tourne dans son propre Pod (conteneur isolé)
2. Chaque Pod a sa propre IP interne Kubernetes
3. L'Ingress (contrôlé par l'ALB) route le trafic Internet :

Route "/" vers le Frontend Service uniquement
Route "/api" vers le Backend Service uniquement

4. Le Backend n'est donc JAMAIS accessible directement depuis Internet, même si son port (5000) est ouvert au niveau du Security Group du Node.
5. Le Security Group ouvre les ports, mais c'est l'Ingress Kubernetes qui décide QUI peut y accéder.
C'est une double couche de sécurité : Security Group AWS + Routage Kubernetes."

┌─────────────────────────────────────────────────────────┐
│  INTERNET                                               │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│  ALB (SG-ALB)                                           │
│  Route tout vers Worker Nodes                           │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│  WORKER NODES (SG-EKS-Nodes)                            │
│  Ports 80 et 5000 ouverts MAIS...                       │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  INGRESS KUBERNETES (Routage intelligent)        │  │
│  │  ├─ "/" → frontend-service                       │  │
│  │  └─ "/api" → backend-service                     │  │
│  └──────────────────┬───────────────┬────────────────┘  │
│                     ↓               ↓                   │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐  │
│  │Pod Frontend  │  │Pod Backend   │  │Pod Worker   │  │
│  │IP: 10.244.x  │  │IP: 10.244.y  │  │IP: 10.244.z │  │
│  │Port: 80      │  │Port: 5000    │  │Pas de port  │  │
│  │Accessible    │  │Via /api      │  │Privé        │  │
│  └──────────────┘  └──────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────────┘

= Pods SÉPARÉS, Nodes PARTAGÉS, Accès CONTRÔLÉS ! ✅
### 📊 Architecture Réseau Complète
┌─────────────────────────────────────────────────────────────┐
│                         VPC 10.0.0.0/16                     │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  SUBNETS PUBLICS (pour ALB)                         │   │
│  │  - subnet-public-1a : 10.0.1.0/24 (us-east-1a)     │   │
│  │  - subnet-public-1b : 10.0.2.0/24 (us-east-1b)     │   │
│  │                                                     │   │
│  │  ┌───────────────────────────────────────────┐     │   │
│  │  │  ALB (Application Load Balancer)          │     │   │
│  │  │  IP Publique                              │     │   │
│  │  └───────────────────────────────────────────┘     │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  SUBNETS PRIVÉS (pour Worker Nodes)                │   │
│  │  - subnet-private-1a : 10.0.3.0/24 (us-east-1a)   │   │
│  │  - subnet-private-1b : 10.0.4.0/24 (us-east-1b)   │   │
│  │                                                     │   │
│  │  ┌──────────────────────┐  ┌──────────────────┐   │   │
│  │  │ WORKER NODE 1        │  │ WORKER NODE 2    │   │   │
│  │  │ EC2 IP: 10.0.3.45    │  │ EC2 IP: 10.0.4.78│   │   │
│  │  │ Subnet: private-1a   │  │ Subnet: private-1b│  │   │
│  │  │                      │  │                  │   │   │
│  │  │  POD Frontend        │  │  POD Frontend    │   │   │
│  │  │  IP: 10.244.1.5      │  │  IP: 10.244.2.3  │   │   │
│  │  │                      │  │                  │   │   │
│  │  │  POD Backend         │  │  POD Backend     │   │   │
│  │  │  IP: 10.244.1.8      │  │  IP: 10.244.2.7  │   │   │
│  │  │                      │  │                  │   │   │
│  │  │  POD Worker          │  │                  │   │   │
│  │  │  IP: 10.244.1.12     │  │                  │   │   │
│  │  └──────────────────────┘  └──────────────────┘   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  SUBNETS PRIVÉS (pour RDS)                          │   │
│  │                                                     │   │
│  │  ┌─────────────────────────────────────────────┐   │   │
│  │  │  RDS MySQL                                  │   │   │
│  │  │  IP: 10.0.3.xxx                             │   │   │
│  │  └─────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
C'est le Node qui "représente" le Pod vers l'extérieur !

### 7. rds.tf 
 "Crée la base de données MySQL managée. AWS gère automatiquement les sauvegardes, mises à jour et haute disponibilité."
### 8. s3.tf 
"Crée le bucket S3 pour les images avec versioning et accès sécurisé via pre-signed URLs."
### 9. ecr.tf 
 "Crée les repositories Docker avec scan de sécurité automatique et lifecycle policy pour optimiser les coûts."
### 10. iam.tf 
"Gère les permissions AWS. Utilise IRSA (IAM Roles for Service Accounts) pour donner des permissions aux Pods Kubernetes sans credentials en dur."
### 11. alb-controller.tf 
 "Installe le AWS Load Balancer Controller via Helm. Permet de créer des ALB automatiquement depuis des Ingress Kubernetes."
### 12. kubernetes-resources.tf 
 "Crée tous les objets Kubernetes : Secrets (credentials), Deployments (applications), Services (réseau interne), Ingress (ALB), HPA (auto-scaling)."
### 13. outputs.tf 
 "Affiche les résultats importants : URL ALB, endpoint RDS, commande kubectl. Facilite l'utilisation après terraform apply."
