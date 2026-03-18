// ============================================================================
// WORKER - SQS Consumer
// ============================================================================
// 
// Worker qui consomme les messages de la queue SQS et les traite
// 
// Fonctionnalités:
//   - Long polling pour économiser les coûts
//   - Retry automatique (3 tentatives)
//   - Envoi à DLQ après échecs
//   - Traitement par type de message
//   - Logging et monitoring
// ============================================================================

const AWS = require('aws-sdk');
const mysql = require('mysql2/promise');

// Configuration
const SQS_QUEUE_URL = process.env.SQS_QUEUE_URL;
const AWS_REGION = process.env.AWS_REGION || 'us-east-1';

// Configuration SQS
const sqs = new AWS.SQS({
  region: AWS_REGION,
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
  }
});

// Configuration S3 (pour génération thumbnails)
const s3 = new AWS.S3({
  region: AWS_REGION,
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
  }
});

// Pool MySQL
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 5
});

// ============================================================================
// CONFIGURATION WORKER
// ============================================================================
const WORKER_CONFIG = {
  pollInterval: 1000,        // 1 seconde entre chaque poll
  maxMessages: 10,           // Max 10 messages par batch
  visibilityTimeout: 300,    // 5 minutes pour traiter un message
  waitTimeSeconds: 20        // Long polling 20 secondes
};

// ============================================================================
// HANDLERS PAR TYPE DE MESSAGE
// ============================================================================

/**
 * Traiter une nouvelle commande
 */
async function handleOrderCreated(data) {
  console.log(`[WORKER] 📦 Traitement commande #${data.orderId}`);
  
  try {
    // ✅ ENVOYER VRAI EMAIL avec AWS SES
    console.log(`[WORKER] 📧 Envoi email confirmation à ${data.userEmail}`);
    
    const emailParams = {
      Source: 'o.elabdi@edu.umi.ac.ma',  // ✅ Votre email vérifié
      Destination: {
        ToAddresses: [data.userEmail]
      },
      Message: {
        Subject: {
          Data: `🎉 Commande #${data.orderId} confirmée !`,
          Charset: 'UTF-8'
        },
        Body: {
          Text: {
            Data: `Bonjour,

Votre commande #${data.orderId} a été confirmée avec succès !

Détails de la commande :
- Montant total : ${data.totalAmount}€
- Nombre d'articles : ${data.itemsCount}
- Adresse de livraison : ${data.shippingAddress}

Merci pour votre confiance !

L'équipe E-Commerce`,
            Charset: 'UTF-8'
          },
          Html: {
            Data: `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
    .order-details { background: white; padding: 20px; border-radius: 5px; margin: 20px 0; }
    .detail-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #eee; }
    .footer { text-align: center; color: #666; padding: 20px; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🎉 Commande Confirmée !</h1>
      <p>Merci pour votre commande</p>
    </div>
    <div class="content">
      <p>Bonjour,</p>
      <p>Votre commande <strong>#${data.orderId}</strong> a été confirmée avec succès !</p>
      
      <div class="order-details">
        <h3>Détails de la commande</h3>
        <div class="detail-row">
          <span>Numéro de commande :</span>
          <strong>#${data.orderId}</strong>
        </div>
        <div class="detail-row">
          <span>Montant total :</span>
          <strong>${data.totalAmount}€</strong>
        </div>
        <div class="detail-row">
          <span>Nombre d'articles :</span>
          <strong>${data.itemsCount}</strong>
        </div>
        <div class="detail-row">
          <span>Adresse de livraison :</span>
          <strong>${data.shippingAddress}</strong>
        </div>
      </div>
      
      <p>Nous préparons votre commande et vous tiendrons informé de son expédition.</p>
      
      <p>Merci pour votre confiance !</p>
      <p><strong>L'équipe E-Commerce</strong></p>
    </div>
    <div class="footer">
      <p>Cet email a été envoyé automatiquement, merci de ne pas y répondre.</p>
      <p>© 2026 E-Commerce Platform - Tous droits réservés</p>
    </div>
  </div>
</body>
</html>`,
            Charset: 'UTF-8'
          }
        }
      }
    };

    // Envoyer l'email via AWS SES
    const AWS = require('aws-sdk');
    const ses = new AWS.SES({ region: 'us-east-1' });
    
    await ses.sendEmail(emailParams).promise();
    
    console.log(`[WORKER] ✅ Email envoyé avec succès à ${data.userEmail}`);
    
    // Insérer notification dans la DB
    await pool.execute(
      `INSERT INTO notifications (user_id, type, message, created_at) 
       VALUES (?, 'order_created', ?, NOW())`,
      [
        data.userId,
        `Votre commande #${data.orderId} a été confirmée (${data.totalAmount}€)`
      ]
    );
    
    console.log(`[WORKER] ✅ Commande #${data.orderId} traitée`);
    return { success: true };
    
  } catch (error) {
    console.error(`[WORKER] ❌ Erreur traitement commande #${data.orderId}`, error);
    throw error;
  }
}

/**
 * Traiter un nouvel utilisateur
 */
async function handleUserRegistered(data) {
  console.log(`[WORKER] 👤 Traitement nouvel utilisateur: ${data.email}`);
  
  try {
    // Simulation envoi email bienvenue
    console.log(`[WORKER] 📧 Envoi email bienvenue à ${data.email}`);
    
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    console.log(`[WORKER] ✅ Utilisateur ${data.email} traité`);
    return { success: true };
    
  } catch (error) {
    console.error(`[WORKER] ❌ Erreur traitement utilisateur ${data.email}`, error);
    throw error;
  }
}

/**
 * Traiter upload image produit (génération thumbnail)
 */
async function handleProductUploaded(data) {
  console.log(`[WORKER] 🖼️  Génération thumbnail pour produit #${data.productId}`);
  
  try {
    // Ici on pourrait utiliser une lib comme 'sharp' pour resize
    // Pour l'instant, on simule juste
    console.log(`[WORKER] 📐 Génération thumbnail de ${data.imageUrl}`);
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Mettre à jour le produit avec l'URL du thumbnail
    // await pool.execute(
    //   'UPDATE products SET thumbnail_url = ? WHERE id = ?',
    //   [thumbnailUrl, data.productId]
    // );
    
    console.log(`[WORKER] ✅ Thumbnail produit #${data.productId} généré`);
    return { success: true };
    
  } catch (error) {
    console.error(`[WORKER] ❌ Erreur génération thumbnail produit #${data.productId}`, error);
    throw error;
  }
}

/**
 * Traiter alerte stock faible
 */
async function handleStockLow(data) {
  console.log(`[WORKER] ⚠️  Alerte stock faible: ${data.name} (${data.currentStock} restants)`);
  
  try {
    // Envoyer email à l'admin
    console.log(`[WORKER] 📧 Envoi alerte stock à admin@ecommerce.com`);
    
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    console.log(`[WORKER] ✅ Alerte stock envoyée pour produit #${data.productId}`);
    return { success: true };
    
  } catch (error) {
    console.error(`[WORKER] ❌ Erreur alerte stock produit #${data.productId}`, error);
    throw error;
  }
}

/**
 * Générer rapport quotidien
 */
async function handleDailyReport(data) {
  console.log(`[WORKER] 📊 Génération rapport quotidien du ${data.date}`);
  
  try {
    // Récupérer stats du jour
    const [stats] = await pool.execute(`
      SELECT 
        COUNT(*) as total_orders,
        SUM(total_amount) as total_revenue,
        AVG(total_amount) as avg_order_value
      FROM orders
      WHERE DATE(created_at) = ?
    `, [data.date]);
    
    console.log(`[WORKER] 📈 Stats du jour:`, stats[0]);
    
    // Ici on pourrait générer un PDF, l'envoyer par email, etc.
    console.log(`[WORKER] 📧 Envoi rapport à admin@ecommerce.com`);
    
    await new Promise(resolve => setTimeout(resolve, 1500));
    
    console.log(`[WORKER] ✅ Rapport quotidien généré`);
    return { success: true, stats: stats[0] };
    
  } catch (error) {
    console.error(`[WORKER] ❌ Erreur génération rapport`, error);
    throw error;
  }
}

/**
 * Envoyer email générique
 */
async function handleEmailSend(data) {
  console.log(`[WORKER] 📧 Envoi email à ${data.to}: ${data.subject}`);
  
  try {
    // Ici on utiliserait AWS SES, SendGrid, ou autre
    console.log(`[WORKER] 📤 Email envoyé à ${data.to}`);
    
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    console.log(`[WORKER] ✅ Email envoyé avec succès`);
    return { success: true };
    
  } catch (error) {
    console.error(`[WORKER] ❌ Erreur envoi email à ${data.to}`, error);
    throw error;
  }
}

// ============================================================================
// ROUTER DES MESSAGES
// ============================================================================
async function processMessage(message) {
  const { type, data, timestamp } = message;
  
  console.log(`[WORKER] 🔄 Traitement message type: ${type}`);
  
  const handlers = {
    'ORDER_CREATED': handleOrderCreated,
    'USER_REGISTERED': handleUserRegistered,
    'PRODUCT_UPLOADED': handleProductUploaded,
    'STOCK_LOW': handleStockLow,
    'DAILY_REPORT': handleDailyReport,
    'EMAIL_SEND': handleEmailSend
  };
  
  const handler = handlers[type];
  
  if (!handler) {
    console.error(`[WORKER] ❌ Type de message inconnu: ${type}`);
    throw new Error(`Unknown message type: ${type}`);
  }
  
  return await handler(data);
}

// ============================================================================
// POLLING SQS
// ============================================================================
async function pollMessages() {
  if (!SQS_QUEUE_URL) {
    console.error('[WORKER] ❌ SQS_QUEUE_URL not configured');
    return;
  }
  
  try {
    const params = {
      QueueUrl: SQS_QUEUE_URL,
      MaxNumberOfMessages: WORKER_CONFIG.maxMessages,
      WaitTimeSeconds: WORKER_CONFIG.waitTimeSeconds,
      VisibilityTimeout: WORKER_CONFIG.visibilityTimeout,
      MessageAttributeNames: ['All']
    };
    
    const result = await sqs.receiveMessage(params).promise();
    
    if (!result.Messages || result.Messages.length === 0) {
      // Pas de messages, attendre un peu
      return;
    }
    
    console.log(`[WORKER] 📥 ${result.Messages.length} message(s) reçu(s)`);
    
    // Traiter chaque message
    for (const sqsMessage of result.Messages) {
      try {
        const message = JSON.parse(sqsMessage.Body);
        
        // Traiter le message
        await processMessage(message);
        
        // Supprimer le message de la queue (succès)
        await sqs.deleteMessage({
          QueueUrl: SQS_QUEUE_URL,
          ReceiptHandle: sqsMessage.ReceiptHandle
        }).promise();
        
        console.log(`[WORKER] ✅ Message supprimé de la queue`);
        
      } catch (error) {
        console.error(`[WORKER] ❌ Erreur traitement message`, error);
        // Le message ne sera PAS supprimé
        // Il redeviendra visible après visibilityTimeout
        // Après 3 échecs, il ira dans la DLQ automatiquement
      }
    }
    
  } catch (error) {
    console.error('[WORKER] ❌ Erreur poll SQS', error);
  }
}

// ============================================================================
// DÉMARRAGE WORKER
// ============================================================================
async function startWorker() {
  console.log('');
  console.log('================================================');
  console.log('🚀 WORKER SQS DÉMARRÉ');
  console.log('================================================');
  console.log(`Queue URL: ${SQS_QUEUE_URL}`);
  console.log(`Region: ${AWS_REGION}`);
  console.log(`Poll interval: ${WORKER_CONFIG.pollInterval}ms`);
  console.log('================================================');
  console.log('');
  
  // Vérifier connexion DB
  try {
    await pool.query('SELECT 1');
    console.log('[WORKER] ✅ Connecté à MySQL');
  } catch (error) {
    console.error('[WORKER] ❌ Erreur connexion MySQL', error);
  }
  
  // Boucle infinie de polling
  while (true) {
    await pollMessages();
    await new Promise(resolve => setTimeout(resolve, WORKER_CONFIG.pollInterval));
  }
}

// ============================================================================
// GESTION SIGNAUX (CTRL+C)
// ============================================================================
process.on('SIGINT', async () => {
  console.log('\n[WORKER] 🛑 Arrêt du worker...');
  await pool.end();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  console.log('\n[WORKER] 🛑 Arrêt du worker...');
  await pool.end();
  process.exit(0);
});

// ============================================================================
// LANCER LE WORKER
// ============================================================================
if (require.main === module) {
  startWorker().catch(error => {
    console.error('[WORKER] ❌ Erreur fatale:', error);
    process.exit(1);
  });
}

module.exports = { startWorker, processMessage };