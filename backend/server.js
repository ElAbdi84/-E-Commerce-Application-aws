// backend/server.js
const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const AWS = require('aws-sdk');
const path = require('path');
const fs = require('fs').promises;
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// Configuration AWS
const s3 = new AWS.S3({
  region: process.env.AWS_REGION || 'us-east-1'
});

const sqs = new AWS.SQS({
  region: process.env.AWS_REGION || 'us-east-1'
});

// Middleware
app.use(cors());
app.use(express.json());

// Servir les fichiers statiques (images)
app.use('/uploads', express.static(path.join(__dirname, 'public/uploads')));

// Configuration MySQL Pool
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'ecommerce',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// Multer pour upload images
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB max
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Seulement les images sont autorisées'));
    }
  }
});

// Middleware d'authentification JWT
const authenticateToken = (req, res, next) => {
  const token = req.headers['authorization']?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Token manquant' });

  jwt.verify(token, process.env.JWT_SECRET || 'secret-key', (err, user) => {
    if (err) return res.status(403).json({ error: 'Token invalide' });
    req.user = user;
    next();
  });
};

// Middleware pour vérifier si admin
const isAdmin = (req, res, next) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Accès refusé. Admin requis.' });
  }
  next();
};

// ===========================
// ROUTES AUTHENTIFICATION
// ===========================

// Inscription
app.post('/api/auth/register', async (req, res) => {
  try {
    const { username, email, password, firstName, lastName } = req.body;

    const hashedPassword = await bcrypt.hash(password, 10);

    const [result] = await pool.execute(
      'INSERT INTO users (username, email, password, first_name, last_name, role) VALUES (?, ?, ?, ?, ?, ?)',
      [username, email, hashedPassword, firstName, lastName, 'customer']
    );

    console.log(`[LOG] Nouvel utilisateur: ${username}`);
    res.status(201).json({ message: 'Utilisateur créé', userId: result.insertId });
  } catch (error) {
    console.error('[ERROR] Registration:', error);
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(400).json({ error: 'Email ou username déjà utilisé' });
    }
    res.status(500).json({ error: 'Erreur lors de l\'inscription' });
  }
});

// Connexion
app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    const [users] = await pool.execute(
      'SELECT * FROM users WHERE email = ?',
      [email]
    );

    if (users.length === 0) {
      return res.status(401).json({ error: 'Email ou mot de passe incorrect' });
    }

    const user = users[0];
    const validPassword = await bcrypt.compare(password, user.password);

    if (!validPassword) {
      return res.status(401).json({ error: 'Email ou mot de passe incorrect' });
    }

    const token = jwt.sign(
      { userId: user.id, username: user.username, role: user.role },
      process.env.JWT_SECRET || 'secret-key',
      { expiresIn: '24h' }
    );

    console.log(`[LOG] Connexion: ${user.username} (${user.role})`);
    res.json({
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role
      }
    });
  } catch (error) {
    console.error('[ERROR] Login:', error);
    res.status(500).json({ error: 'Erreur lors de la connexion' });
  }
});

// Récupérer les informations de l'utilisateur connecté
app.get('/api/auth/me', authenticateToken, async (req, res) => {
  try {
    const [users] = await pool.execute(
      'SELECT id, username, email, first_name, last_name, role, created_at FROM users WHERE id = ?',
      [req.user.userId]
    );

    if (users.length === 0) {
      return res.status(404).json({ error: 'Utilisateur non trouvé' });
    }

    res.json(users[0]);
  } catch (error) {
    console.error('[ERROR] Get user info:', error);
    res.status(500).json({ error: 'Erreur récupération utilisateur' });
  }
});

// ===========================
// ROUTES CATÉGORIES
// ===========================

// Récupérer toutes les catégories
app.get('/api/categories', async (req, res) => {
  try {
    const [categories] = await pool.execute(
      'SELECT * FROM categories ORDER BY name'
    );
    res.json(categories);
  } catch (error) {
    console.error('[ERROR] Get categories:', error);
    res.status(500).json({ error: 'Erreur récupération catégories' });
  }
});

// Créer une catégorie (Admin seulement)
app.post('/api/categories', authenticateToken, isAdmin, async (req, res) => {
  try {
    const { name, description } = req.body;

    const [result] = await pool.execute(
      'INSERT INTO categories (name, description) VALUES (?, ?)',
      [name, description]
    );

    console.log(`[LOG] Catégorie créée: ${name}`);
    res.status(201).json({ message: 'Catégorie créée', categoryId: result.insertId });
  } catch (error) {
    console.error('[ERROR] Create category:', error);
    res.status(500).json({ error: 'Erreur création catégorie' });
  }
});

// ===========================
// ROUTES PRODUITS
// ===========================

// Récupérer tous les produits (avec filtres optionnels)
app.get('/api/products', async (req, res) => {
  try {
    const { category, search, minPrice, maxPrice } = req.query;

    let query = `
      SELECT p.*, c.name as category_name 
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id 
      WHERE 1=1
    `;
    const params = [];

    if (category) {
      query += ' AND p.category_id = ?';
      params.push(category);
    }

    if (search) {
      query += ' AND (p.name LIKE ? OR p.description LIKE ?)';
      params.push(`%${search}%`, `%${search}%`);
    }

    if (minPrice) {
      query += ' AND p.price >= ?';
      params.push(minPrice);
    }

    if (maxPrice) {
      query += ' AND p.price <= ?';
      params.push(maxPrice);
    }

    query += ' ORDER BY p.created_at DESC';

    const [products] = await pool.execute(query, params);

    // ✅ NOUVEAU : Générer URLs signées pour les images S3
    const productsWithUrls = products.map(product => {
      if (
        product.image_url &&
        !product.image_url.startsWith('http') // C'est une KEY S3, pas une URL
      ) {
        product.image_url = s3.getSignedUrl('getObject', {
          Bucket: process.env.S3_BUCKET_NAME,
          Key: product.image_url,
          Expires: 3600 // URL valable 1 heure
        });
      }
      return product;
    });

    console.log(`[LOG] ${products.length} produits récupérés`);
    res.json(productsWithUrls); // ✅ Envoie avec URLs signées
  } catch (error) {
    console.error('[ERROR] Get products:', error);
    res.status(500).json({ error: 'Erreur récupération produits' });
  }
});

// Récupérer un produit par ID
app.get('/api/products/:id', async (req, res) => {
  try {
    const [products] = await pool.execute(
      `SELECT p.*, c.name as category_name 
       FROM products p 
       LEFT JOIN categories c ON p.category_id = c.id 
       WHERE p.id = ?`,
      [req.params.id]
    );

    if (products.length === 0) {
      return res.status(404).json({ error: 'Produit non trouvé' });
    }

    const product = products[0];

    // ✅ NOUVEAU : Générer URL signée si image S3
    if (
      product.image_url &&
      !product.image_url.startsWith('http')
    ) {
      product.image_url = s3.getSignedUrl('getObject', {
        Bucket: process.env.S3_BUCKET_NAME,
        Key: product.image_url,
        Expires: 3600
      });
    }

    res.json(product);
  } catch (error) {
    console.error('[ERROR] Get product:', error);
    res.status(500).json({ error: 'Erreur récupération produit' });
  }
});

// Créer un produit (Admin seulement)
app.post('/api/products', authenticateToken, isAdmin, async (req, res) => {
  try {
    const { name, description, price, stock, categoryId } = req.body;

    const [result] = await pool.execute(
      'INSERT INTO products (name, description, price, stock, category_id) VALUES (?, ?, ?, ?, ?)',
      [name, description, price, stock, categoryId]
    );

    console.log(`[LOG] Produit créé: ${name}`);
    res.status(201).json({ message: 'Produit créé', productId: result.insertId });
  } catch (error) {
    console.error('[ERROR] Create product:', error);
    res.status(500).json({ error: 'Erreur création produit' });
  }
});

// Mettre à jour un produit (Admin seulement)
app.put('/api/products/:id', authenticateToken, isAdmin, async (req, res) => {
  try {
    const { name, description, price, stock, categoryId } = req.body;

    await pool.execute(
      'UPDATE products SET name = ?, description = ?, price = ?, stock = ?, category_id = ? WHERE id = ?',
      [name, description, price, stock, categoryId, req.params.id]
    );

    console.log(`[LOG] Produit ${req.params.id} mis à jour`);
    res.json({ message: 'Produit mis à jour' });
  } catch (error) {
    console.error('[ERROR] Update product:', error);
    res.status(500).json({ error: 'Erreur mise à jour produit' });
  }
});

// Supprimer un produit (Admin seulement)
app.delete('/api/products/:id', authenticateToken, isAdmin, async (req, res) => {
  try {
    await pool.execute('DELETE FROM products WHERE id = ?', [req.params.id]);

    console.log(`[LOG] Produit ${req.params.id} supprimé`);
    res.json({ message: 'Produit supprimé' });
  } catch (error) {
    console.error('[ERROR] Delete product:', error);
    res.status(500).json({ error: 'Erreur suppression produit' });
  }
});

// Upload image produit (Admin seulement) - VERSION CORRIGÉE
app.post('/api/products/:id/image', authenticateToken, isAdmin, upload.single('image'), async (req, res) => {
  try {
    const { id } = req.params;
    const file = req.file;

    if (!file) {
      return res.status(400).json({ error: 'Aucune image fournie' });
    }

    console.log(`[LOG] Tentative upload image pour produit ${id}`);

    // Vérifier si on utilise S3 ou stockage local
    const useS3 = process.env.S3_BUCKET_NAME && process.env.AWS_ACCESS_KEY_ID;

    if (useS3) {
      console.log('[LOG] Mode S3 activé');
      // Upload vers S3
      const s3Key = `products/${id}/${Date.now()}-${file.originalname}`;
      const s3Params = {
        Bucket: process.env.S3_BUCKET_NAME,
        Key: s3Key,
        Body: file.buffer,
        ContentType: file.mimetype
      };

      const s3Result = await s3.upload(s3Params).promise();

      // Stocker la KEY S3 (pas l'URL complète)
      await pool.execute(
        'UPDATE products SET image_url = ? WHERE id = ?',
        [s3Key, id]  // ← Stocke juste la KEY : "products/17/xxx.jpg"
      );

      console.log(`[LOG] Image uploadée vers S3 pour produit ${id}`);
      res.json({ message: 'Image uploadée', url: s3Result.Location });

    } else {
      console.log('[LOG] Mode stockage local activé');
      // Stockage local (développement)
      const fileName = `${Date.now()}-${file.originalname.replace(/\s/g, '-')}`;
      const uploadDir = path.join(__dirname, 'public', 'uploads', 'products');
      const uploadPath = path.join(uploadDir, fileName);

      // Créer le dossier s'il n'existe pas
      await fs.mkdir(uploadDir, { recursive: true });

      // Sauvegarder le fichier
      await fs.writeFile(uploadPath, file.buffer);

      const imageUrl = `http://localhost:${PORT}/uploads/products/${fileName}`;

      // Mettre à jour dans la base
      await pool.execute(
        'UPDATE products SET image_url = ? WHERE id = ?',
        [imageUrl, id]
      );

      console.log(`[LOG] Image sauvegardée localement: ${fileName}`);
      console.log(`[LOG] URL: ${imageUrl}`);
      res.json({ message: 'Image uploadée', url: imageUrl });
    }

  } catch (error) {
    console.error('[ERROR] Upload image:', error);
    console.error('[ERROR] Stack:', error.stack);
    res.status(500).json({ error: 'Erreur upload image: ' + error.message });
  }
});

// ===========================
// ROUTES PANIER
// ===========================

// Récupérer le panier de l'utilisateur
app.get('/api/cart', authenticateToken, async (req, res) => {
  try {
    const [items] = await pool.execute(
      `SELECT c.*, p.name, p.price, p.image_url, p.stock,
              (c.quantity * p.price) as subtotal
       FROM cart_items c
       JOIN products p ON c.product_id = p.id
       WHERE c.user_id = ?`,
      [req.user.userId]
    );

    const total = items.reduce((sum, item) => sum + parseFloat(item.subtotal), 0);

    res.json({ items, total });
  } catch (error) {
    console.error('[ERROR] Get cart:', error);
    res.status(500).json({ error: 'Erreur récupération panier' });
  }
});

// Ajouter un produit au panier
app.post('/api/cart', authenticateToken, async (req, res) => {
  try {
    const { productId, quantity } = req.body;

    // Vérifier le stock
    const [products] = await pool.execute(
      'SELECT stock FROM products WHERE id = ?',
      [productId]
    );

    if (products.length === 0) {
      return res.status(404).json({ error: 'Produit non trouvé' });
    }

    if (products[0].stock < quantity) {
      return res.status(400).json({ error: 'Stock insuffisant' });
    }

    // Vérifier si le produit est déjà dans le panier
    const [existing] = await pool.execute(
      'SELECT * FROM cart_items WHERE user_id = ? AND product_id = ?',
      [req.user.userId, productId]
    );

    if (existing.length > 0) {
      // Mettre à jour la quantité
      await pool.execute(
        'UPDATE cart_items SET quantity = quantity + ? WHERE user_id = ? AND product_id = ?',
        [quantity, req.user.userId, productId]
      );
    } else {
      // Ajouter au panier
      await pool.execute(
        'INSERT INTO cart_items (user_id, product_id, quantity) VALUES (?, ?, ?)',
        [req.user.userId, productId, quantity]
      );
    }

    console.log(`[LOG] Produit ${productId} ajouté au panier de user ${req.user.userId}`);
    res.status(201).json({ message: 'Produit ajouté au panier' });
  } catch (error) {
    console.error('[ERROR] Add to cart:', error);
    res.status(500).json({ error: 'Erreur ajout au panier' });
  }
});

// Mettre à jour la quantité dans le panier
app.put('/api/cart/:productId', authenticateToken, async (req, res) => {
  try {
    const { quantity } = req.body;

    if (quantity <= 0) {
      // Supprimer du panier
      await pool.execute(
        'DELETE FROM cart_items WHERE user_id = ? AND product_id = ?',
        [req.user.userId, req.params.productId]
      );
    } else {
      // Mettre à jour la quantité
      await pool.execute(
        'UPDATE cart_items SET quantity = ? WHERE user_id = ? AND product_id = ?',
        [quantity, req.user.userId, req.params.productId]
      );
    }

    res.json({ message: 'Panier mis à jour' });
  } catch (error) {
    console.error('[ERROR] Update cart:', error);
    res.status(500).json({ error: 'Erreur mise à jour panier' });
  }
});

// Vider le panier
app.delete('/api/cart', authenticateToken, async (req, res) => {
  try {
    await pool.execute(
      'DELETE FROM cart_items WHERE user_id = ?',
      [req.user.userId]
    );

    console.log(`[LOG] Panier vidé pour user ${req.user.userId}`);
    res.json({ message: 'Panier vidé' });
  } catch (error) {
    console.error('[ERROR] Clear cart:', error);
    res.status(500).json({ error: 'Erreur vidage panier' });
  }
});

// ===========================
// ROUTES COMMANDES
// ===========================

// Créer une commande (Checkout)
app.post('/api/orders', authenticateToken, async (req, res) => {
  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    const { shippingAddress, paymentMethod } = req.body;

    // Récupérer les items du panier
    const [cartItems] = await connection.execute(
      `SELECT c.*, p.price, p.stock 
       FROM cart_items c 
       JOIN products p ON c.product_id = p.id 
       WHERE c.user_id = ?`,
      [req.user.userId]
    );

    if (cartItems.length === 0) {
      await connection.rollback();
      return res.status(400).json({ error: 'Panier vide' });
    }

    // Vérifier le stock pour tous les produits
    for (const item of cartItems) {
      if (item.stock < item.quantity) {
        await connection.rollback();
        return res.status(400).json({
          error: `Stock insuffisant pour ${item.name}`
        });
      }
    }

    // Calculer le total
    const total = cartItems.reduce((sum, item) =>
      sum + (item.price * item.quantity), 0
    );

    // Créer la commande
    const [orderResult] = await connection.execute(
      `INSERT INTO orders (user_id, total_amount, status, shipping_address, payment_method) 
       VALUES (?, ?, ?, ?, ?)`,
      [req.user.userId, total, 'pending', shippingAddress, paymentMethod]
    );

    const orderId = orderResult.insertId;

    // Créer les order_items et mettre à jour le stock
    for (const item of cartItems) {
      await connection.execute(
        `INSERT INTO order_items (order_id, product_id, quantity, price) 
         VALUES (?, ?, ?, ?)`,
        [orderId, item.product_id, item.quantity, item.price]
      );

      await connection.execute(
        'UPDATE products SET stock = stock - ? WHERE id = ?',
        [item.quantity, item.product_id]
      );
    }

    // Vider le panier
    await connection.execute(
      'DELETE FROM cart_items WHERE user_id = ?',
      [req.user.userId]
    );

    await connection.commit();

    console.log(`[LOG] Commande ${orderId} créée par user ${req.user.userId}`);

    // Envoyer message à SQS pour email de confirmation
    if (process.env.SQS_QUEUE_URL) {
      const params = {
        QueueUrl: process.env.SQS_QUEUE_URL,
        MessageBody: JSON.stringify({
          type: 'ORDER_CREATED',
          orderId: orderId,
          userId: req.user.userId,
          totalAmount: total,
          items: cartItems.length
        })
      };

      await sqs.sendMessage(params).promise();
      console.log('[LOG] Message SQS envoyé pour confirmation email');
    }

    res.status(201).json({
      message: 'Commande créée avec succès',
      orderId,
      total
    });

  } catch (error) {
    await connection.rollback();
    console.error('[ERROR] Create order:', error);
    res.status(500).json({ error: 'Erreur création commande' });
  } finally {
    connection.release();
  }
});

// Récupérer les commandes de l'utilisateur
app.get('/api/orders', authenticateToken, async (req, res) => {
  try {
    const [orders] = await pool.execute(
      `SELECT o.*, 
              COUNT(oi.id) as items_count
       FROM orders o
       LEFT JOIN order_items oi ON o.id = oi.order_id
       WHERE o.user_id = ?
       GROUP BY o.id
       ORDER BY o.created_at DESC`,
      [req.user.userId]
    );

    res.json(orders);
  } catch (error) {
    console.error('[ERROR] Get orders:', error);
    res.status(500).json({ error: 'Erreur récupération commandes' });
  }
});

// Récupérer les détails d'une commande
app.get('/api/orders/:id', authenticateToken, async (req, res) => {
  try {
    const [orders] = await pool.execute(
      'SELECT * FROM orders WHERE id = ? AND user_id = ?',
      [req.params.id, req.user.userId]
    );

    if (orders.length === 0) {
      return res.status(404).json({ error: 'Commande non trouvée' });
    }

    const [items] = await pool.execute(
      `SELECT oi.*, p.name, p.image_url 
       FROM order_items oi
       JOIN products p ON oi.product_id = p.id
       WHERE oi.order_id = ?`,
      [req.params.id]
    );

    res.json({ order: orders[0], items });
  } catch (error) {
    console.error('[ERROR] Get order details:', error);
    res.status(500).json({ error: 'Erreur récupération détails' });
  }
});

// ===========================
// ROUTE HEALTH CHECK
// ===========================

app.get('/health', async (req, res) => {
  try {
    await pool.execute('SELECT 1');
    res.json({
      status: 'healthy',
      database: 'connected',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({
      status: 'unhealthy',
      database: 'disconnected',
      error: error.message
    });
  }
});

// Route pour les statistiques (Admin)
app.get('/api/stats', authenticateToken, isAdmin, async (req, res) => {
  try {
    const [productCount] = await pool.execute('SELECT COUNT(*) as count FROM products');
    const [orderCount] = await pool.execute('SELECT COUNT(*) as count FROM orders');
    const [userCount] = await pool.execute('SELECT COUNT(*) as count FROM users');
    const [revenue] = await pool.execute('SELECT SUM(total_amount) as total FROM orders WHERE status = "completed"');

    res.json({
      products: productCount[0].count,
      orders: orderCount[0].count,
      users: userCount[0].count,
      revenue: revenue[0].total || 0
    });
  } catch (error) {
    console.error('[ERROR] Get stats:', error);
    res.status(500).json({ error: 'Erreur récupération statistiques' });
  }
});

// ===========================
// DÉMARRAGE SERVEUR
// ===========================

app.listen(PORT, () => {
  console.log(`✅ Backend E-commerce API sur port ${PORT}`);
  console.log(`📊 Environnement: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🗄️  Base: ${process.env.DB_HOST || 'localhost'}`);
  console.log(`📁 Upload: Mode ${process.env.S3_BUCKET_NAME ? 'S3' : 'Local'}`);
  console.log(`📂 Dossier uploads: ${path.join(__dirname, 'public', 'uploads')}`);
});