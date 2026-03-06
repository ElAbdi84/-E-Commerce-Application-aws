# 🚀 Guide de Déploiement - Projet E-Commerce PFE

## 📋 Vue d'Ensemble

Ce document décrit toutes les étapes pour déployer l'application e-commerce sur AWS avec Kubernetes (EKS) et Terraform.

---

## ✅ Prérequis

### **Outils Requis**

```bash
# 1. Terraform >= 1.7.0
terraform version

# 2. AWS CLI >= 2.0
aws --version

# 3. kubectl >= 1.28
kubectl version --client

# 4. Helm >= 3.12
helm version

# 5. Docker >= 24.0
docker --version

# 6. Git
git --version
```

### **Configuration AWS**

```bash
# Configurer AWS CLI
aws configure

# Vérifier l'identité
aws sts get-caller-identity

# Résultat attendu :
# {
#     "UserId": "AIDAXXXXXXXXX",
#     "Account": "714454206137",
#     "Arn": "arn:aws:iam::714454206137:user/OumaymaAdmin"
# }
```

---

## 📁 Structure du Projet

```
ecommerce-pfe/
├── backend/              # API Node.js + Express
│   ├── server.js
│   ├── init-db.js
│   ├── package.json
│   └── Dockerfile
├── frontend/             # React 18 + Nginx
│   ├── src/
│   ├── public/
│   ├── nginx.conf
│   ├── package.json
│   └── Dockerfile
├── worker/               # SQS Consumer
│   ├── worker.js
│   ├── package.json
│   └── Dockerfile
├── terraform/            # Infrastructure as Code
│   ├── *.tf
│   └── terraform.tfvars
└── docs/                 # Documentation
    ├── architecture.md
    ├── deployment.md
    └── api.md
```

---

## 🎯 Étapes de Déploiement

### **Partie 1 : Préparation (15 min)**

#### **1.1 Cloner le Projet**

```bash
cd ~
git clone https://github.com/votre-username/ecommerce-pfe.git
cd ecommerce-pfe
```

#### **1.2 Configurer terraform.tfvars**

```bash
cd terraform
cp terraform.tfvars.template terraform.tfvars
nano terraform.tfvars
```

**Valeurs à personnaliser :**

```hcl
# GÉNÉRAL
project_name = "ecommerce-pfe"
aws_region   = "us-east-1"

# RDS
db_password = "VotreMotDePasseSecurise123!"  # ← CHANGEZ

# S3 (nom UNIQUE globalement)
s3_bucket_name = "ecommerce-products-votrenom-2026"  # ← CHANGEZ

# SECRETS
jwt_secret = "genere-un-secret-fort-32-caracteres-minimum"  # ← CHANGEZ
aws_access_key_id     = "AKIAXXXXXXXXXXXXXXXX"  # ← VOS CREDENTIALS
aws_secret_access_key = "xxxxxxxxxxxxxxxx"      # ← VOS CREDENTIALS
```

**Générer JWT Secret :**

```bash
# Option 1 : Node.js
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

# Option 2 : OpenSSL
openssl rand -hex 32
```

#### **1.3 Configurer .gitignore**

```bash
# Dans terraform/
cat > .gitignore << 'EOF'
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
terraform.tfvars
*.auto.tfvars
EOF
```

---

### **Partie 2 : Infrastructure avec Terraform (40 min)**

#### **2.1 Initialiser Terraform**

```bash
cd ~/ecommerce-pfe/terraform
terraform init
```

**Résultat attendu :**
```
Terraform has been successfully initialized!
```

#### **2.2 Valider la Configuration**

```bash
terraform validate
```

**Résultat attendu :**
```
Success! The configuration is valid.
```

#### **2.3 Prévisualiser les Changements**

```bash
terraform plan
```

**Vérifier :**
- ~50-60 ressources à créer
- Aucune erreur

#### **2.4 Créer l'Infrastructure**

```bash
terraform apply
```

**Confirmation :**
```
Do you want to perform these actions?
  Enter a value: yes  ← Tapez "yes"
```

**⏱️ Durée : 30-40 minutes**

**Ressources créées :**
```
✅ VPC + Subnets (publics/privés)
✅ Internet Gateway + NAT Gateway
✅ Security Groups (ALB, EKS Nodes, RDS)
✅ RDS MySQL (10 min)
✅ S3 Bucket
✅ ECR Repositories
✅ IAM Roles + Policies
✅ EKS Cluster (15 min)
✅ Worker Nodes (5 min)
✅ ALB Controller (Helm)
✅ Kubernetes Resources (Deployments, Services, Ingress, HPA)
```

**Résultat final :**
```
Apply complete! Resources: 52 added, 0 changed, 0 destroyed.

Outputs:

configure_kubectl = "aws eks update-kubeconfig --region us-east-1 --name ecommerce-cluster"
eks_cluster_endpoint = "https://xxxxx.gr7.us-east-1.eks.amazonaws.com"
eks_cluster_name = "ecommerce-cluster"
s3_bucket_name = "ecommerce-products-xxx"
vpc_id = "vpc-xxxxxxxxxxxxx"
```

---

### **Partie 3 : Configuration Kubernetes (5 min)**

#### **3.1 Configurer kubectl**

```bash
# Utiliser la commande fournie par Terraform
aws eks update-kubeconfig --region us-east-1 --name ecommerce-cluster

# Vérifier
kubectl cluster-info
kubectl get nodes
```

**Résultat attendu :**
```
NAME                         STATUS   ROLES    AGE   VERSION
ip-10-0-3-xxx.ec2.internal   Ready    <none>   5m    v1.31.x
ip-10-0-4-xxx.ec2.internal   Ready    <none>   5m    v1.31.x
```

#### **3.2 Vérifier les Pods**

```bash
kubectl get pods
```

**État initial (normal) :**
```
NAME                                   READY   STATUS             RESTARTS   AGE
backend-deployment-xxxxx-yyyyy         0/1     ImagePullBackOff   0          2m
backend-deployment-xxxxx-zzzzz         0/1     ImagePullBackOff   0          2m
frontend-deployment-xxxxx-aaaaa        0/1     ImagePullBackOff   0          2m
frontend-deployment-xxxxx-bbbbb        0/1     ImagePullBackOff   0          2m
worker-deployment-xxxxx-ccccc          0/1     ImagePullBackOff   0          2m
```

**C'est normal ! Les images Docker n'existent pas encore dans ECR.**

---

### **Partie 4 : Build et Push Images Docker (10 min)**

#### **4.1 Login Docker à ECR**

```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  714454206137.dkr.ecr.us-east-1.amazonaws.com
```

#### **4.2 Build et Push Backend**

```bash
cd ~/ecommerce-pfe/backend

# Build
docker build -t ecommerce-backend:latest .

# Tag
docker tag ecommerce-backend:latest \
  714454206137.dkr.ecr.us-east-1.amazonaws.com/ecommerce-backend:latest

# Push
docker push 714454206137.dkr.ecr.us-east-1.amazonaws.com/ecommerce-backend:latest
```

#### **4.3 Build et Push Frontend**

```bash
cd ~/ecommerce-pfe/frontend

# Build avec variable d'environnement
docker build --build-arg REACT_APP_API_URL="/api" -t ecommerce-frontend:latest .

# Tag
docker tag ecommerce-frontend:latest \
  714454206137.dkr.ecr.us-east-1.amazonaws.com/ecommerce-frontend:latest

# Push
docker push 714454206137.dkr.ecr.us-east-1.amazonaws.com/ecommerce-frontend:latest
```

#### **4.4 Build et Push Worker**

```bash
cd ~/ecommerce-pfe/worker

# Build
docker build -t ecommerce-worker:latest .

# Tag
docker tag ecommerce-worker:latest \
  714454206137.dkr.ecr.us-east-1.amazonaws.com/ecommerce-worker:latest

# Push
docker push 714454206137.dkr.ecr.us-east-1.amazonaws.com/ecommerce-worker:latest
```

#### **4.5 Vérifier les Images dans ECR**

```bash
aws ecr list-images --repository-name ecommerce-backend --region us-east-1
aws ecr list-images --repository-name ecommerce-frontend --region us-east-1
aws ecr list-images --repository-name ecommerce-worker --region us-east-1
```

---

### **Partie 5 : Démarrer les Applications (2 min)**

#### **5.1 Redémarrer les Deployments**

```bash
kubectl rollout restart deployment/backend-deployment
kubectl rollout restart deployment/frontend-deployment
kubectl rollout restart deployment/worker-deployment
```

#### **5.2 Vérifier le Démarrage**

```bash
# Surveiller en temps réel
kubectl get pods -w

# Attendre que tous soient Running (1-2 min)
# Ctrl+C pour arrêter la surveillance
```

**Résultat attendu :**
```
NAME                                   READY   STATUS    RESTARTS   AGE
backend-deployment-xxxxx-yyyyy         1/1     Running   0          1m
backend-deployment-xxxxx-zzzzz         1/1     Running   0          1m
frontend-deployment-xxxxx-aaaaa        1/1     Running   0          1m
frontend-deployment-xxxxx-bbbbb        1/1     Running   0          1m
worker-deployment-xxxxx-ccccc          1/1     Running   0          1m
```

---

### **Partie 6 : Initialiser la Base de Données (2 min)**

#### **6.1 Exécuter le Script d'Initialisation**

```bash
# Copier le script dans le Pod Backend
kubectl cp backend/init-db.js \
  $(kubectl get pod -l app=backend -o jsonpath='{.items[0].metadata.name}'):/app/init-db.js

# Exécuter
kubectl exec \
  $(kubectl get pod -l app=backend -o jsonpath='{.items[0].metadata.name}') \
  -- node init-db.js
```

**Résultat attendu :**
```
✅ Base de données 'ecommerce' créée
✅ Table users créée
✅ Table categories créée
✅ Table products créée
✅ 15 produits créés avec images
✅ Admin créé (email: admin@ecommerce.com, password: admin123)
```

---

### **Partie 7 : Accéder à l'Application (1 min)**

#### **7.1 Obtenir l'URL ALB**

```bash
kubectl get ingress ecommerce-ingress
```

**Résultat :**
```
NAME                CLASS   HOSTS   ADDRESS                                          PORTS   AGE
ecommerce-ingress   alb     *       k8s-default-ecommerc-xxxxx.us-east-1.elb.amazonaws.com   80      10m
```

#### **7.2 Ouvrir dans le Navigateur**

```
http://k8s-default-ecommerc-xxxxx.us-east-1.elb.amazonaws.com
```

**✅ Votre application e-commerce devrait s'afficher avec 15 produits ! 🎉**

---

## ✅ Vérifications Post-Déploiement

### **1. Vérifier les Pods**

```bash
kubectl get pods
# Tous doivent être Running avec READY 1/1
```

### **2. Vérifier les Services**

```bash
kubectl get services
# backend-service et frontend-service doivent être ClusterIP
```

### **3. Vérifier l'Ingress**

```bash
kubectl get ingress
# Doit avoir une ADDRESS (URL ALB)
```

### **4. Vérifier HPA**

```bash
kubectl get hpa
# backend-hpa et frontend-hpa doivent afficher les métriques
```

### **5. Tester le Backend API**

```bash
# Via ALB
curl http://k8s-default-ecommerc-xxxxx.us-east-1.elb.amazonaws.com/api/products

# Doit retourner JSON avec liste produits
```

### **6. Tester le Frontend**

Ouvrir dans le navigateur et vérifier :
- ✅ Page d'accueil s'affiche
- ✅ 15 produits visibles
- ✅ Images Unsplash chargent
- ✅ Navigation fonctionne

### **7. Tester la Connexion Admin**

```
Email: admin@ecommerce.com
Password: admin123
```

---

## 📊 Commandes Utiles

### **Monitoring**

```bash
# Voir les logs d'un Pod
kubectl logs -f <pod-name>

# Logs Backend
kubectl logs -l app=backend --tail=50

# Logs Frontend
kubectl logs -l app=frontend --tail=50

# Métriques CPU/RAM
kubectl top nodes
kubectl top pods

# Événements
kubectl get events --sort-by='.lastTimestamp' | tail -20
```

### **Debug**

```bash
# Détails d'un Pod
kubectl describe pod <pod-name>

# Shell dans un Pod
kubectl exec -it <pod-name> -- sh

# Port-forward (test local)
kubectl port-forward svc/backend-service 5000:5000
kubectl port-forward svc/frontend-service 3000:80
```

### **Scaling Manuel**

```bash
# Scaler Backend
kubectl scale deployment/backend-deployment --replicas=3

# Scaler Frontend
kubectl scale deployment/frontend-deployment --replicas=4
```

---

## 🐛 Dépannage

### **Problème 1 : Pods en ImagePullBackOff**

**Cause :** Images pas dans ECR

**Solution :**
```bash
# Vérifier images ECR
aws ecr list-images --repository-name ecommerce-backend --region us-east-1

# Si vide, build et push (Partie 4)
```

### **Problème 2 : Pods en CrashLoopBackOff**

**Cause :** Erreur applicative

**Solution :**
```bash
# Voir les logs
kubectl logs <pod-name>

# Causes communes :
# - Mauvaises credentials RDS
# - Port déjà utilisé
# - Erreur dans le code
```

###** Problème 3 : Ingress sans ADDRESS**

**Cause :** ALB Controller pas prêt

**Solution :**
```bash
# Vérifier ALB Controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Voir les logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Attendre 2-3 minutes
```

### **Problème 4 : Frontend affiche "Aucun produit trouvé"**

**Cause :** Base de données vide

**Solution :**
```bash
# Initialiser la DB (Partie 6)
kubectl exec $(kubectl get pod -l app=backend -o jsonpath='{.items[0].metadata.name}') -- node init-db.js
```

### **Problème 5 : 504 Gateway Timeout**

**Cause :** Target Group Unhealthy

**Solution :**
```bash
# Vérifier Target Groups dans AWS Console
# EC2 → Target Groups → Vérifier Health Status

# Causes communes :
# - Security Groups mal configurés
# - Health check path incorrect
# - Pods pas Ready
```

---

## 🗑️ Nettoyage (Destroy)

### **Détruire l'Infrastructure**

```bash
cd ~/ecommerce-pfe/terraform
terraform destroy
```

**Confirmation :**
```
Do you really want to destroy all resources?
  Enter a value: yes  ← Tapez "yes"
```

**⏱️ Durée : 10-15 minutes**

**Ressources supprimées :**
- Cluster EKS + Nodes
- ALB + Target Groups
- RDS MySQL
- NAT Gateway + Elastic IP
- VPC + Subnets
- Security Groups
- IAM Roles

**Ressources à supprimer manuellement (si nécessaire) :**
- Images ECR (terraform destroy ne les supprime pas)
- S3 Bucket (si contient des fichiers)

---

## 📈 Mise à Jour de l'Application

### **Déployer une Nouvelle Version**

```bash
# 1. Modifier le code (backend, frontend, worker)

# 2. Build nouvelle image avec nouveau tag
docker build -t ecommerce-backend:v2 backend/
docker tag ecommerce-backend:v2 714454206137.dkr.ecr.us-east-1.amazonaws.com/ecommerce-backend:v2
docker push 714454206137.dkr.ecr.us-east-1.amazonaws.com/ecommerce-backend:v2

# 3. Mettre à jour l'image dans Kubernetes
kubectl set image deployment/backend-deployment backend=714454206137.dkr.ecr.us-east-1.amazonaws.com/ecommerce-backend:v2

# 4. Vérifier le rolling update
kubectl rollout status deployment/backend-deployment

# 5. Rollback si problème
kubectl rollout undo deployment/backend-deployment
```

---

## 💰 Gestion des Coûts

### **Économiser en Dev**

```bash
# Arrêter RDS (max 7 jours)
aws rds stop-db-instance --db-instance-identifier ecommerce-db

# Redémarrer RDS
aws rds start-db-instance --db-instance-identifier ecommerce-db

# Détruire infrastructure quand inutilisée
terraform destroy
```

### **Coûts Mensuels (si toujours actif)**

```
EKS Control Plane : $72/mois
Worker Nodes : ~$30/mois
RDS : $15/mois (ou Free Tier)
NAT Gateway : ~$32/mois
ALB : ~$20/mois
TOTAL : ~$170/mois

Avec destroy quand inutilisé : ~$20-30/mois
```

---

## 📚 Prochaines Étapes

- **Partie 6** : CI/CD avec GitHub Actions
- **Partie 7** : Traitement Asynchrone (SQS)
- **Partie 8** : Monitoring (CloudWatch, Prometheus)
- **Partie 9** : Sécurité Avancée (WAF, HTTPS)

---

**Auteur** : Oumayma El Abdi  
**Date** : Mars 2026  
**Version** : 1.0