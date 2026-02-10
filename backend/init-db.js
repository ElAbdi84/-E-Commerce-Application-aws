// backend/init-db.js (VERSION AVEC IMAGES)
const mysql = require('mysql2/promise');
const bcrypt = require('bcrypt');
require('dotenv').config();

async function initDatabase() {
  let connection;
  
  try {
    console.log('🔄 Connexion à MySQL...');
    
    connection = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || 'password'
    });

    console.log('✅ Connexion MySQL réussie');

    const dbName = process.env.DB_NAME || 'ecommerce';
    await connection.query(`CREATE DATABASE IF NOT EXISTS ${dbName}`);
    console.log(`✅ Base de données '${dbName}' créée`);

    await connection.query(`USE ${dbName}`);

    // Table users
    console.log('📝 Création table users...');
    await connection.query(`
      CREATE TABLE IF NOT EXISTS users (
        id INT PRIMARY KEY AUTO_INCREMENT,
        username VARCHAR(50) UNIQUE NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        first_name VARCHAR(50),
        last_name VARCHAR(50),
        role ENUM('customer', 'admin') DEFAULT 'customer',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_email (email),
        INDEX idx_role (role)
      )
    `);
    console.log('✅ Table users créée');

    // Table categories
    console.log('📝 Création table categories...');
    await connection.query(`
      CREATE TABLE IF NOT EXISTS categories (
        id INT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(100) UNIQUE NOT NULL,
        description TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_name (name)
      )
    `);
    console.log('✅ Table categories créée');

    // Table products
    console.log('📝 Création table products...');
    await connection.query(`
      CREATE TABLE IF NOT EXISTS products (
        id INT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(200) NOT NULL,
        description TEXT,
        price DECIMAL(10, 2) NOT NULL,
        stock INT DEFAULT 0,
        image_url VARCHAR(500),
        category_id INT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
        INDEX idx_category (category_id),
        INDEX idx_price (price),
        INDEX idx_name (name)
      )
    `);
    console.log('✅ Table products créée');

    // Table cart_items
    console.log('📝 Création table cart_items...');
    await connection.query(`
      CREATE TABLE IF NOT EXISTS cart_items (
        id INT PRIMARY KEY AUTO_INCREMENT,
        user_id INT NOT NULL,
        product_id INT NOT NULL,
        quantity INT NOT NULL DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
        UNIQUE KEY unique_user_product (user_id, product_id),
        INDEX idx_user (user_id)
      )
    `);
    console.log('✅ Table cart_items créée');

    // Table orders
    console.log('📝 Création table orders...');
    await connection.query(`
      CREATE TABLE IF NOT EXISTS orders (
        id INT PRIMARY KEY AUTO_INCREMENT,
        user_id INT NOT NULL,
        total_amount DECIMAL(10, 2) NOT NULL,
        status ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled') DEFAULT 'pending',
        shipping_address TEXT NOT NULL,
        payment_method VARCHAR(50),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        INDEX idx_user (user_id),
        INDEX idx_status (status),
        INDEX idx_created (created_at)
      )
    `);
    console.log('✅ Table orders créée');

    // Table order_items
    console.log('📝 Création table order_items...');
    await connection.query(`
      CREATE TABLE IF NOT EXISTS order_items (
        id INT PRIMARY KEY AUTO_INCREMENT,
        order_id INT NOT NULL,
        product_id INT NOT NULL,
        quantity INT NOT NULL,
        price DECIMAL(10, 2) NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT,
        INDEX idx_order (order_id)
      )
    `);
    console.log('✅ Table order_items créée');

    // ===========================
    // DONNÉES DE TEST AVEC IMAGES
    // ===========================

    console.log('\n📦 Insertion des données de test...');

    // Créer un utilisateur admin
    const adminPassword = await bcrypt.hash('admin123', 10);
    await connection.query(`
      INSERT IGNORE INTO users (username, email, password, first_name, last_name, role) 
      VALUES ('admin', 'admin@ecommerce.com', ?, 'Admin', 'User', 'admin')
    `, [adminPassword]);
    console.log('✅ Admin créé (email: admin@ecommerce.com, password: admin123)');

    // Créer un client de test
    const userPassword = await bcrypt.hash('user123', 10);
    await connection.query(`
      INSERT IGNORE INTO users (username, email, password, first_name, last_name, role) 
      VALUES ('john_doe', 'john@example.com', ?, 'John', 'Doe', 'customer')
    `, [userPassword]);
    console.log('✅ Client test créé (email: john@example.com, password: user123)');

    // Créer des catégories
    const categories = [
      ['Électronique', 'Produits électroniques et gadgets'],
      ['Vêtements', 'Mode et accessoires'],
      ['Maison', 'Articles pour la maison'],
      ['Sports', 'Équipement sportif'],
      ['Livres', 'Livres et magazines']
    ];

    for (const [name, description] of categories) {
      await connection.query(
        'INSERT IGNORE INTO categories (name, description) VALUES (?, ?)',
        [name, description]
      );
    }
    console.log('✅ 5 catégories créées');

    // Créer des produits avec IMAGES (URLs Unsplash)
    const products = [
      [
        'Laptop HP 15', 
        'Ordinateur portable performant avec processeur Intel i7, 16GB RAM, SSD 512GB', 
        899.99, 
        10, 
        1,
        'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=500&auto=format&fit=crop'
      ],
      [
        'iPhone 15 Pro', 
        'Smartphone dernière génération avec puce A17 Pro, caméra 48MP', 
        1199.99, 
        5, 
        1,
        'https://images.unsplash.com/photo-1678685888221-cda773a3dcdb?w=500&auto=format&fit=crop'
      ],
      [
        'Sony Headphones WH-1000XM5', 
        'Casque audio sans fil avec réduction de bruit active', 
        199.99, 
        20, 
        1,
        'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500&auto=format&fit=crop'
      ],
      [
        'Apple Watch Series 9', 
        'Montre connectée avec capteur de santé avancé', 
        449.99, 
        15, 
        1,
        'https://images.unsplash.com/photo-1434494878577-86c23bcb06b9?w=500&auto=format&fit=crop'
      ],
      [
        'T-shirt Nike Dri-FIT', 
        'T-shirt sport confortable et respirant', 
        29.99, 
        50, 
        2,
        'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=500&auto=format&fit=crop'
      ],
      [
        'Jean Levis 501', 
        'Jean classique de qualité premium', 
        79.99, 
        30, 
        2,
        'https://images.unsplash.com/photo-1542272604-787c3835535d?w=500&auto=format&fit=crop'
      ],
      [
        'Sneakers Adidas Ultraboost', 
        'Chaussures de running confortables', 
        149.99, 
        25, 
        2,
        'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=500&auto=format&fit=crop'
      ],
      [
        'Chaise Bureau Ergonomique', 
        'Chaise de bureau avec support lombaire réglable', 
        149.99, 
        15, 
        3,
        'https://images.unsplash.com/photo-1580480055273-228ff5388ef8?w=500&auto=format&fit=crop'
      ],
      [
        'Lampe LED Design', 
        'Lampe de bureau moderne avec luminosité ajustable', 
        39.99, 
        35, 
        3,
        'https://images.unsplash.com/photo-1507473885765-e6ed057f782c?w=500&auto=format&fit=crop'
      ],
      [
        'Ballon Football Nike', 
        'Ballon de football officiel taille 5', 
        24.99, 
        40, 
        4,
        'https://images.unsplash.com/photo-1614632537197-38a17061c2bd?w=500&auto=format&fit=crop'
      ],
      [
        'Raquette Tennis Wilson', 
        'Raquette de tennis professionnelle', 
        89.99, 
        12, 
        4,
        'https://images.unsplash.com/photo-1617083278159-30cf96383dd4?w=500&auto=format&fit=crop'
      ],
      [
        'Yoga Mat Premium', 
        'Tapis de yoga antidérapant 6mm', 
        34.99, 
        50, 
        4,
        'https://images.unsplash.com/photo-1601925260368-ae2f83cf8b7f?w=500&auto=format&fit=crop'
      ],
      [
        'Python Programming Guide', 
        'Livre complet pour apprendre Python', 
        39.99, 
        25, 
        5,
        'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?w=500&auto=format&fit=crop'
      ],
      [
        'JavaScript: The Definitive Guide', 
        'Guide de référence JavaScript', 
        44.99, 
        20, 
        5,
        'https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=500&auto=format&fit=crop'
      ],
      [
        'Design Thinking Magazine', 
        'Magazine mensuel sur le design', 
        9.99, 
        100, 
        5,
        'https://images.unsplash.com/photo-1457369804613-52c61a468e7d?w=500&auto=format&fit=crop'
      ]
    ];

    for (const [name, description, price, stock, categoryId, imageUrl] of products) {
      await connection.query(
        'INSERT IGNORE INTO products (name, description, price, stock, category_id, image_url) VALUES (?, ?, ?, ?, ?, ?)',
        [name, description, price, stock, categoryId, imageUrl]
      );
    }
    console.log('✅ 15 produits créés avec images');

    console.log('\n🎉 Base de données initialisée avec succès !');
    console.log('\n📊 Résumé :');
    console.log('   - 2 utilisateurs (1 admin, 1 client)');
    console.log('   - 5 catégories');
    console.log('   - 15 produits avec images');
    console.log('\n🔐 Connexion Admin :');
    console.log('   Email: admin@ecommerce.com');
    console.log('   Password: admin123');
    console.log('   Rôle: admin (accès complet)');
    console.log('\n👤 Connexion Client :');
    console.log('   Email: john@example.com');
    console.log('   Password: user123');
    console.log('   Rôle: customer (pas d\'accès admin)');
    console.log('\n🖼️  Images :');
    console.log('   Toutes les images sont hébergées sur Unsplash');
    console.log('   Elles s\'afficheront automatiquement dans l\'interface');
    
  } catch (error) {
    console.error('❌ Erreur lors de l\'initialisation:', error.message);
    process.exit(1);
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n✅ Connexion fermée');
    }
  }
}

initDatabase();