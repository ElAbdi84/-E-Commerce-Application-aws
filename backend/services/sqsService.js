// ============================================================================
// SQS SERVICE - Backend Publisher
// ============================================================================
// 
// Service pour envoyer des messages à SQS depuis le Backend
// 
// Usage:
//   const sqsService = require('./services/sqsService');
//   await sqsService.sendMessage('ORDER_CREATED', { orderId: 123 });
// ============================================================================

const AWS = require('aws-sdk');

// Configuration SQS
const sqs = new AWS.SQS({
    region: process.env.AWS_REGION || 'us-east-1',
    credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
    }
});

const QUEUE_URL = process.env.SQS_QUEUE_URL;

// ============================================================================
// TYPES DE MESSAGES
// ============================================================================
const MESSAGE_TYPES = {
    ORDER_CREATED: 'ORDER_CREATED',           // Nouvelle commande
    USER_REGISTERED: 'USER_REGISTERED',       // Nouvel utilisateur
    PRODUCT_UPLOADED: 'PRODUCT_UPLOADED',     // Upload image produit
    STOCK_LOW: 'STOCK_LOW',                   // Stock faible
    DAILY_REPORT: 'DAILY_REPORT',             // Rapport quotidien
    EMAIL_SEND: 'EMAIL_SEND'                  // Envoyer email générique
};

// ============================================================================
// ENVOYER UN MESSAGE
// ============================================================================
async function sendMessage(messageType, data, options = {}) {
    if (!QUEUE_URL) {
        console.error('[SQS] ❌ SQS_QUEUE_URL not configured');
        return null;
    }

    try {
        const message = {
            type: messageType,
            data: data,
            timestamp: new Date().toISOString(),
            metadata: {
                source: 'backend',
                environment: process.env.NODE_ENV || 'development',
                ...options.metadata
            }
        };

        const params = {
            QueueUrl: QUEUE_URL,
            MessageBody: JSON.stringify(message),
            MessageAttributes: {
                MessageType: {
                    DataType: 'String',
                    StringValue: messageType
                }
            },
            // Délai optionnel (0-900 secondes)
            DelaySeconds: options.delay || 0
        };

        const result = await sqs.sendMessage(params).promise();

        console.log(`[SQS] ✅ Message envoyé: ${messageType}`, {
            messageId: result.MessageId,
            data: data
        });

        return result.MessageId;

    } catch (error) {
        console.error(`[SQS] ❌ Erreur envoi message: ${messageType}`, error);
        throw error;
    }
}

// ============================================================================
// HELPERS SPÉCIFIQUES PAR TYPE DE MESSAGE
// ============================================================================

/**
 * Envoyer notification nouvelle commande
 */
async function sendOrderCreatedMessage(order) {
    return sendMessage(MESSAGE_TYPES.ORDER_CREATED, {
        orderId: order.id,
        userId: order.user_id,
        totalAmount: order.total_amount,
        itemsCount: order.items_count,
        userEmail: order.user_email,
        shippingAddress: order.shipping_address
    });
}

/**
 * Envoyer notification nouvel utilisateur
 */
async function sendUserRegisteredMessage(user) {
    return sendMessage(MESSAGE_TYPES.USER_REGISTERED, {
        userId: user.id,
        email: user.email,
        username: user.username,
        firstName: user.first_name,
        lastName: user.last_name
    });
}

/**
 * Envoyer job génération thumbnail
 */
async function sendProductUploadedMessage(product) {
    return sendMessage(MESSAGE_TYPES.PRODUCT_UPLOADED, {
        productId: product.id,
        imageUrl: product.image_url,
        name: product.name
    });
}

/**
 * Envoyer alerte stock faible
 */
async function sendStockLowMessage(product) {
    return sendMessage(MESSAGE_TYPES.STOCK_LOW, {
        productId: product.id,
        name: product.name,
        currentStock: product.stock,
        threshold: 10
    });
}

/**
 * Envoyer job rapport quotidien
 */
async function sendDailyReportMessage() {
    return sendMessage(MESSAGE_TYPES.DAILY_REPORT, {
        date: new Date().toISOString().split('T')[0],
        reportType: 'daily_sales'
    });
}

/**
 * Envoyer email générique
 */
async function sendEmailMessage(to, subject, body, template = null) {
    return sendMessage(MESSAGE_TYPES.EMAIL_SEND, {
        to,
        subject,
        body,
        template
    });
}

// ============================================================================
// OBTENIR STATISTIQUES DE LA QUEUE
// ============================================================================
async function getQueueStats() {
    if (!QUEUE_URL) {
        return null;
    }

    try {
        const params = {
            QueueUrl: QUEUE_URL,
            AttributeNames: [
                'ApproximateNumberOfMessages',
                'ApproximateNumberOfMessagesNotVisible',
                'ApproximateNumberOfMessagesDelayed'
            ]
        };

        const result = await sqs.getQueueAttributes(params).promise();

        return {
            messagesAvailable: parseInt(result.Attributes.ApproximateNumberOfMessages || 0),
            messagesInFlight: parseInt(result.Attributes.ApproximateNumberOfMessagesNotVisible || 0),
            messagesDelayed: parseInt(result.Attributes.ApproximateNumberOfMessagesDelayed || 0),
            queueUrl: QUEUE_URL
        };

    } catch (error) {
        console.error('[SQS] ❌ Erreur récupération stats queue', error);
        return null;
    }
}

// ============================================================================
// EXPORTS
// ============================================================================
module.exports = {
    MESSAGE_TYPES,
    sendMessage,
    sendOrderCreatedMessage,
    sendUserRegisteredMessage,
    sendProductUploadedMessage,
    sendStockLowMessage,
    sendDailyReportMessage,
    sendEmailMessage,
    getQueueStats
};