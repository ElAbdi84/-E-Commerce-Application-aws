# 📡 Documentation API - Projet E-Commerce PFE

## 📋 Vue d'Ensemble

API REST pour le projet e-commerce, développée avec Node.js + Express.

**Base URL :** `http://k8s-default-ecommerc-xxxxx.us-east-1.elb.amazonaws.com/api`

---

## 🔐 Authentification

### **JWT (JSON Web Token)**

L'API utilise JWT pour l'authentification. Après connexion, incluez le token dans l'header :

```http
Authorization: Bearer <votre-token-jwt>
```

### **Rôles**

- **customer** : Utilisateur normal (achats, commandes)
- **admin** : Administrateur (gestion produits, catégories)

---

## 📚 Endpoints

### **1. Authentification**

#### **POST /api/auth/register**

Créer un nouveau compte utilisateur.

**Request Body :**
```json
{
  "email": "user@example.com",
  "password": "password123",
  "firstName": "John",
  "lastName": "Doe"
}
```

**Response (201 Created) :**
```json
{
  "message": "Utilisateur créé avec succès",
  "user": {
    "id": 3,
    "email": "user@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "role": "customer"
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Errors :**
- `400 Bad Request` : Email déjà utilisé
- `400 Bad Request` : Données manquantes

---

#### **POST /api/auth/login**

Se connecter avec email et mot de passe.

**Request Body :**
```json
{
  "email": "admin@ecommerce.com",
  "password": "admin123"
}
```

**Response (200 OK) :**
```json
{
  "message": "Connexion réussie",
  "user": {
    "id": 1,
    "email": "admin@ecommerce.com",
    "firstName": "Admin",
    "lastName": "System",
    "role": "admin"
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Errors :**
- `401 Unauthorized` : Email ou mot de passe incorrect

---

#### **GET /api/auth/me**

Obtenir les informations de l'utilisateur connecté.

**Headers :**
```http
Authorization: Bearer <token>
```

**Response (200 OK) :**
```json
{
  "id": 1,
  "email": "admin@ecommerce.com",
  "firstName": "Admin",
  "lastName": "System",
  "role": "admin",
  "createdAt": "2026-02-25T10:00:00.000Z"
}
```

---

### **2. Produits**

#### **GET /api/products**

Liste tous les produits.

**Query Parameters :**
- `category` (optional) : Filtrer par catégorie ID
- `search` (optional) : Rechercher par nom
- `minPrice` (optional) : Prix minimum
- `maxPrice` (optional) : Prix maximum
- `limit` (optional) : Nombre de résultats (default: 50)
- `offset` (optional) : Pagination (default: 0)

**Example :**
```http
GET /api/products?category=1&search=iphone&limit=10
```

**Response (200 OK) :**
```json
[
  {
    "id": 36,
    "name": "iPhone 15 Pro",
    "description": "Smartphone dernière génération avec puce A17 Pro",
    "price": "1199.99",
    "stock": 5,
    "image_url": "https://images.unsplash.com/photo-xxx",
    "category_id": 1,
    "category_name": "Électronique",
    "created_at": "2026-02-23T15:30:34.000Z",
    "updated_at": "2026-02-23T15:30:34.000Z"
  },
  ...
]
```

---

#### **GET /api/products/:id**

Détails d'un produit spécifique.

**Response (200 OK) :**
```json
{
  "id": 36,
  "name": "iPhone 15 Pro",
  "description": "Smartphone dernière génération avec puce A17 Pro, caméra 48MP",
  "price": "1199.99",
  "stock": 5,
  "image_url": "https://images.unsplash.com/photo-xxx",
  "category_id": 1,
  "category_name": "Électronique",
  "created_at": "2026-02-23T15:30:34.000Z",
  "updated_at": "2026-02-23T15:30:34.000Z"
}
```

**Errors :**
- `404 Not Found` : Produit non trouvé

---

#### **POST /api/products**

Créer un nouveau produit (admin seulement).

**Headers :**
```http
Authorization: Bearer <admin-token>
Content-Type: multipart/form-data
```

**Request Body (Form Data) :**
```
name: "iPhone 16 Pro"
description: "Nouveau modèle 2026"
price: 1299.99
stock: 10
category_id: 1
image: <file>
```

**Response (201 Created) :**
```json
{
  "id": 51,
  "name": "iPhone 16 Pro",
  "description": "Nouveau modèle 2026",
  "price": "1299.99",
  "stock": 10,
  "image_url": "https://ecommerce-products-xxx.s3.amazonaws.com/products/xxx.jpg",
  "category_id": 1,
  "created_at": "2026-03-04T10:00:00.000Z",
  "updated_at": "2026-03-04T10:00:00.000Z"
}
```

**Errors :**
- `401 Unauthorized` : Non authentifié
- `403 Forbidden` : Pas admin
- `400 Bad Request` : Données manquantes

---

#### **PUT /api/products/:id**

Modifier un produit (admin seulement).

**Headers :**
```http
Authorization: Bearer <admin-token>
Content-Type: application/json
```

**Request Body :**
```json
{
  "name": "iPhone 15 Pro Max",
  "price": 1399.99,
  "stock": 8
}
```

**Response (200 OK) :**
```json
{
  "id": 36,
  "name": "iPhone 15 Pro Max",
  "description": "Smartphone dernière génération avec puce A17 Pro",
  "price": "1399.99",
  "stock": 8,
  "image_url": "https://images.unsplash.com/photo-xxx",
  "category_id": 1,
  "updated_at": "2026-03-04T10:30:00.000Z"
}
```

**Errors :**
- `404 Not Found` : Produit non trouvé
- `403 Forbidden` : Pas admin

---

#### **DELETE /api/products/:id**

Supprimer un produit (admin seulement).

**Headers :**
```http
Authorization: Bearer <admin-token>
```

**Response (200 OK) :**
```json
{
  "message": "Produit supprimé avec succès"
}
```

**Errors :**
- `404 Not Found` : Produit non trouvé
- `403 Forbidden` : Pas admin

---

### **3. Catégories**

#### **GET /api/categories**

Liste toutes les catégories.

**Response (200 OK) :**
```json
[
  {
    "id": 1,
    "name": "Électronique",
    "description": "Produits électroniques et high-tech",
    "product_count": 5
  },
  {
    "id": 2,
    "name": "Vêtements",
    "description": "Mode et vêtements",
    "product_count": 3
  }
]
```

---

#### **POST /api/categories**

Créer une catégorie (admin seulement).

**Headers :**
```http
Authorization: Bearer <admin-token>
Content-Type: application/json
```

**Request Body :**
```json
{
  "name": "Sports",
  "description": "Équipements sportifs"
}
```

**Response (201 Created) :**
```json
{
  "id": 6,
  "name": "Sports",
  "description": "Équipements sportifs",
  "created_at": "2026-03-04T10:00:00.000Z"
}
```

---

### **4. Panier**

#### **GET /api/cart**

Afficher le panier de l'utilisateur connecté.

**Headers :**
```http
Authorization: Bearer <token>
```

**Response (200 OK) :**
```json
{
  "items": [
    {
      "id": 12,
      "product_id": 36,
      "product_name": "iPhone 15 Pro",
      "product_price": "1199.99",
      "product_image": "https://images.unsplash.com/photo-xxx",
      "quantity": 2,
      "subtotal": 2399.98
    }
  ],
  "total": 2399.98
}
```

---

#### **POST /api/cart**

Ajouter un produit au panier.

**Headers :**
```http
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body :**
```json
{
  "product_id": 36,
  "quantity": 1
}
```

**Response (201 Created) :**
```json
{
  "message": "Produit ajouté au panier",
  "item": {
    "id": 13,
    "product_id": 36,
    "quantity": 1
  }
}
```

---

#### **PUT /api/cart/:itemId**

Modifier la quantité d'un article du panier.

**Headers :**
```http
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body :**
```json
{
  "quantity": 3
}
```

**Response (200 OK) :**
```json
{
  "message": "Quantité mise à jour",
  "item": {
    "id": 13,
    "quantity": 3
  }
}
```

---

#### **DELETE /api/cart/:itemId**

Supprimer un article du panier.

**Headers :**
```http
Authorization: Bearer <token>
```

**Response (200 OK) :**
```json
{
  "message": "Article supprimé du panier"
}
```

---

### **5. Commandes**

#### **GET /api/orders**

Liste des commandes de l'utilisateur connecté.

**Headers :**
```http
Authorization: Bearer <token>
```

**Response (200 OK) :**
```json
[
  {
    "id": 5,
    "total": "2399.98",
    "status": "pending",
    "created_at": "2026-03-04T09:00:00.000Z",
    "items": [
      {
        "product_id": 36,
        "product_name": "iPhone 15 Pro",
        "quantity": 2,
        "price": "1199.99"
      }
    ]
  }
]
```

---

#### **POST /api/orders**

Créer une commande depuis le panier.

**Headers :**
```http
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body :**
```json
{
  "shipping_address": "123 Rue Example, Casablanca",
  "payment_method": "card"
}
```

**Response (201 Created) :**
```json
{
  "message": "Commande créée avec succès",
  "order": {
    "id": 6,
    "total": "2399.98",
    "status": "pending",
    "created_at": "2026-03-04T10:00:00.000Z"
  }
}
```

**Errors :**
- `400 Bad Request` : Panier vide
- `400 Bad Request` : Stock insuffisant

---

#### **GET /api/orders/:id**

Détails d'une commande spécifique.

**Headers :**
```http
Authorization: Bearer <token>
```

**Response (200 OK) :**
```json
{
  "id": 5,
  "user_id": 2,
  "total": "2399.98",
  "status": "pending",
  "shipping_address": "123 Rue Example, Casablanca",
  "payment_method": "card",
  "created_at": "2026-03-04T09:00:00.000Z",
  "items": [
    {
      "product_id": 36,
      "product_name": "iPhone 15 Pro",
      "product_image": "https://images.unsplash.com/photo-xxx",
      "quantity": 2,
      "price": "1199.99",
      "subtotal": 2399.98
    }
  ]
}
```

---

### **6. Health Check**

#### **GET /api/health**

Vérifier l'état de l'API et de la connexion DB.

**Response (200 OK) :**
```json
{
  "status": "healthy",
  "database": "connected",
  "timestamp": "2026-03-04T10:00:00.000Z"
}
```

**Response (500 Error) si DB déconnectée :**
```json
{
  "status": "unhealthy",
  "database": "disconnected",
  "error": "Connection refused"
}
```

---

## 🔒 Codes d'Erreur

| Code | Description |
|------|-------------|
| **200** | OK - Succès |
| **201** | Created - Ressource créée |
| **400** | Bad Request - Données invalides |
| **401** | Unauthorized - Non authentifié |
| **403** | Forbidden - Pas les permissions |
| **404** | Not Found - Ressource non trouvée |
| **500** | Internal Server Error - Erreur serveur |

---

## 📊 Format des Réponses d'Erreur

```json
{
  "error": "Message d'erreur détaillé",
  "code": "ERROR_CODE",
  "details": {
    "field": "valeur problématique"
  }
}
```

**Exemples :**

```json
{
  "error": "Email déjà utilisé",
  "code": "DUPLICATE_EMAIL"
}
```

```json
{
  "error": "Produit non trouvé",
  "code": "PRODUCT_NOT_FOUND"
}
```

---

## 🧪 Exemples d'Utilisation

### **Avec cURL**

#### **Connexion**
```bash
curl -X POST http://your-alb-url/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@ecommerce.com","password":"admin123"}'
```

#### **Liste Produits**
```bash
curl http://your-alb-url/api/products
```

#### **Créer Produit (Admin)**
```bash
curl -X POST http://your-alb-url/api/products \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name":"Nouveau Produit",
    "description":"Description",
    "price":99.99,
    "stock":10,
    "category_id":1
  }'
```

---

### **Avec JavaScript (Fetch)**

```javascript
// Connexion
const login = async () => {
  const response = await fetch('http://your-alb-url/api/auth/login', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      email: 'admin@ecommerce.com',
      password: 'admin123'
    })
  });
  
  const data = await response.json();
  return data.token;
};

// Récupérer produits
const getProducts = async (token) => {
  const response = await fetch('http://your-alb-url/api/products', {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  
  return await response.json();
};
```

---

### **Avec Postman**

1. **Collection** : Créer une collection "E-Commerce API"
2. **Environment** : 
   - `base_url` : votre URL ALB
   - `token` : JWT token après login
3. **Auth** : Bearer Token → `{{token}}`

---

## 📈 Rate Limiting

Actuellement **aucune limite** (dev environment).

En production, implémenter :
- **100 requêtes/minute** par IP
- **1000 requêtes/heure** par utilisateur authentifié

---

## 🔐 Sécurité

### **Bonnes Pratiques**

✅ **HTTPS en production** (ACM + ALB)  
✅ **CORS configuré** pour Frontend  
✅ **JWT avec expiration** (24h)  
✅ **Hash passwords** (bcrypt)  
✅ **Validation inputs** (express-validator)  
✅ **SQL Injection protection** (parameterized queries)  

### **Headers de Sécurité**

```http
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
```

---

## 📚 Ressources

- **Code Source** : backend/server.js
- **Tests** : backend/__tests__/
- **Postman Collection** : docs/postman/ecommerce-api.json

---

**Auteur** : Oumayma El Abdi  
**Date** : Mars 2026  
**Version** : 1.0