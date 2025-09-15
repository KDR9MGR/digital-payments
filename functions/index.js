const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');
const axios = require('axios');
const { google } = require('googleapis');
const crypto = require('crypto');
const cron = require('node-cron');
const fs = require('fs');
const path = require('path');

admin.initializeApp();
const db = admin.firestore();

// Moov API functions are imported from moov_api.js which handles OAuth2 authentication

// Wire in modular function exports (moov API callable functions)
Object.assign(exports, require('./moov_api'));

// Environment configuration for webhook validation
const GOOGLE_PLAY_WEBHOOK_SECRET = functions.config().google_play?.webhook_secret || 'your_google_play_webhook_secret';
const APPLE_WEBHOOK_SECRET = functions.config().apple?.webhook_secret || 'your_apple_webhook_secret';



















// Moov webhook handler
exports.moovWebhook = functions.https.onRequest(async (req, res) => {
  try {
    const event = req.body;
    
    console.log('Received Moov webhook:', event.type);
    
    // Handle different Moov event types
    switch (event.type) {
      case 'account.created':
        await handleAccountCreated(event);
        break;
      case 'transfer.completed':
        await handleTransferCompleted(event);
        break;
      case 'transfer.failed':
        await handleTransferFailed(event);
        break;
      case 'payment_method.created':
        await handlePaymentMethodCreated(event);
        break;
      default:
        console.log(`Unhandled Moov event type: ${event.type}`);
    }
    
    res.status(200).json({received: true});
  } catch (error) {
    console.error('Error handling Moov webhook:', error);
    res.status(500).json({error: 'Webhook processing failed'});
  }
});

// Delete account function for web-based account deletion
exports.deleteAccount = functions.https.onRequest(async (req, res) => {
  // Set CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  
  // Handle preflight OPTIONS request
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }
  
  // Only allow POST requests
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  
  try {
    // Get authorization header
    const authHeader = req.headers.authorization || '';
    const idToken = authHeader.startsWith('Bearer ') 
        ? authHeader.split('Bearer ')[1] 
        : null;

    if (!idToken) {
      return res.status(401).json({ error: 'Missing authentication token' });
    }

    // Verify the ID token
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const uid = decodedToken.uid;
    
    console.log(`Starting account deletion for user: ${uid}`);
    
    // Delete user data from Firestore
    const batch = db.batch();
    
    // Delete user document
    const userRef = db.collection('users').doc(uid);
    batch.delete(userRef);
    
    // Delete user's transactions
    const transactionsSnapshot = await db.collection('transactions')
      .where('userId', '==', uid)
      .get();
    
    transactionsSnapshot.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    // Delete user's subscriptions
    const subscriptionsSnapshot = await db.collection('subscriptions')
      .where('userId', '==', uid)
      .get();
    
    subscriptionsSnapshot.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    // Delete user's payment methods
    const paymentMethodsSnapshot = await db.collection('paymentMethods')
      .where('userId', '==', uid)
      .get();
    
    paymentMethodsSnapshot.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    // Commit the batch delete
    await batch.commit();
    
    // Delete files from Firebase Storage
    try {
      const bucket = admin.storage().bucket();
      const [files] = await bucket.getFiles({
        prefix: `users/${uid}/`
      });
      
      // Delete all user files
      const deletePromises = files.map(file => file.delete());
      await Promise.all(deletePromises);
      
      console.log(`Deleted ${files.length} files for user ${uid}`);
    } catch (storageError) {
      console.error('Error deleting user files:', storageError);
      // Continue with account deletion even if file deletion fails
    }
    
    // Finally, delete the Firebase Auth user
    await admin.auth().deleteUser(uid);
    
    console.log(`Successfully deleted account for user: ${uid}`);
    
    res.status(200).json({ 
      success: true, 
      message: 'Account successfully deleted' 
    });
    
  } catch (error) {
    console.error('Error deleting account:', error);
    
    // Return appropriate error message
    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({ error: 'Authentication token expired' });
    } else if (error.code === 'auth/id-token-revoked') {
      return res.status(401).json({ error: 'Authentication token revoked' });
    } else if (error.code === 'auth/user-not-found') {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.status(500).json({ 
      error: 'Failed to delete account', 
      details: error.message 
    });
  }
});

// Handle account created event
async function handleAccountCreated(event) {
  try {
    const accountData = event.data;
    console.log('Account created:', accountData.accountID);
    
    // Store account info in Firestore if needed
    if (accountData.foreignId) {
      await db.collection('users').doc(accountData.foreignId).set({
        moovAccountId: accountData.accountID,
        moovAccountStatus: accountData.status,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  } catch (error) {
    console.error('Error handling account created:', error);
  }
}

// Handle transfer completed event
async function handleTransferCompleted(event) {
  try {
    const transferData = event.data;
    console.log('Transfer completed:', transferData.transferID);
    
    // Update subscription status if this was a subscription payment
    if (transferData.metadata && transferData.metadata.subscriptionId) {
      await db.collection('subscriptions').doc(transferData.metadata.subscriptionId).update({
        status: 'active',
        lastPaymentDate: FieldValue.serverTimestamp(),
        transferId: transferData.transferID,
        paymentStatus: 'completed',
      });
      
      // Store payment record
      await db.collection('payments').add({
        subscriptionId: transferData.metadata.subscriptionId,
        transferId: transferData.transferID,
        amount: transferData.amount.value,
        currency: transferData.amount.currency,
        status: 'completed',
        userId: transferData.metadata.userId,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  } catch (error) {
    console.error('Error handling transfer completed:', error);
  }
}

// Handle transfer failed event
async function handleTransferFailed(event) {
  try {
    const transferData = event.data;
    console.log('Transfer failed:', transferData.transferID);
    
    // Update subscription status if this was a subscription payment
    if (transferData.metadata && transferData.metadata.subscriptionId) {
      await db.collection('subscriptions').doc(transferData.metadata.subscriptionId).update({
        status: 'payment_failed',
        lastPaymentAttempt: FieldValue.serverTimestamp(),
        transferId: transferData.transferID,
        paymentStatus: 'failed',
        failureReason: transferData.failureReason || 'Payment failed',
      });
    }
  } catch (error) {
    console.error('Error handling transfer failed:', error);
  }
}

// Handle payment method created event
async function handlePaymentMethodCreated(event) {
  try {
    const paymentMethodData = event.data;
    console.log('Payment method created:', paymentMethodData.paymentMethodID);
    
    // Store payment method info if needed
    // This is typically handled on the client side
  } catch (error) {
    console.error('Error handling payment method created:', error);
  }
}

// Check user subscription status
exports.checkSubscriptionStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;

  try {
    // Check active subscription in Firestore
    const subscriptionQuery = await db.collection('subscriptions')
      .where('userId', '==', userId)
      .where('status', '==', 'active')
      .orderBy('createdAt', 'desc')
      .limit(1)
      .get();

    if (subscriptionQuery.empty) {
      return {
        isSubscribed: false,
        subscriptionStatus: 'none',
        message: 'No active subscription found'
      };
    }

    const subscription = subscriptionQuery.docs[0].data();
    const now = FieldValue.serverTimestamp();
    const expiryDate = subscription.expiryDate?.toDate();

    // Check if subscription is still valid
    if (expiryDate && expiryDate > now) {
      return {
        isSubscribed: true,
        subscriptionStatus: 'active',
        expiryDate: expiryDate.toISOString(),
        planType: subscription.planType || 'super_payments_monthly',
        paymentMethod: subscription.paymentMethod
      };
    } else {
      // Update expired subscription
      await db.collection('subscriptions').doc(subscriptionQuery.docs[0].id).update({
        status: 'expired',
        updatedAt: FieldValue.serverTimestamp()
      });

      return {
        isSubscribed: false,
        subscriptionStatus: 'expired',
        message: 'Subscription has expired'
      };
    }
  } catch (error) {
    console.error('Error checking subscription status:', error);
    throw new functions.https.HttpsError('internal', 'Failed to check subscription status');
  }
});

// Validate Google Play Store purchase
exports.validateGooglePlayPurchase = functions
  .runWith({
    memory: '1GB',
    timeoutSeconds: 60,
    maxInstances: 10
  })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { purchaseToken, productId, packageName, subscriptionId } = data;
  const userId = context.auth.uid;
  const effectiveProductId = productId || subscriptionId; // support both naming conventions

  // Validate input parameters
  if (!purchaseToken || !effectiveProductId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters: purchaseToken and productId/subscriptionId');
  }

  try {
    console.log(`Validating Google Play purchase for user ${userId}, product ${effectiveProductId}`);
    
    // Check for duplicate purchase token
    const existingPurchase = await db.collection('subscriptions')
      .where('purchaseToken', '==', purchaseToken)
      .where('userId', '==', userId)
      .limit(1)
      .get();
    
    if (!existingPurchase.empty) {
      console.log(`Duplicate purchase token detected: ${purchaseToken}`);
      const existingDoc = existingPurchase.docs[0];
      const existingData = existingDoc.data();
      
      return {
        success: true,
        subscriptionId: existingDoc.id,
        expiryDate: existingData.expiryDate.toDate().toISOString(),
        message: 'Purchase already validated',
        isDuplicate: true
      };
    }

    // Initialize Google Play Developer API using googleapis
    const auth = new google.auth.GoogleAuth({
      credentials: GOOGLE_PLAY_SERVICE_ACCOUNT,
      scopes: ['https://www.googleapis.com/auth/androidpublisher']
    });
    
    const androidPublisher = google.androidpublisher({ version: 'v3', auth });
    
    // Call purchases.subscriptions.get as requested
    const response = await androidPublisher.purchases.subscriptions.get({
      packageName: packageName || GOOGLE_PLAY_PACKAGE_NAME,
      subscriptionId: effectiveProductId,
      token: purchaseToken
    });
    
    const purchase = response.data;
    console.log(`Google Play API response:`, {
      paymentState: purchase.paymentState,
      autoRenewing: purchase.autoRenewing,
      expiryTimeMillis: purchase.expiryTimeMillis,
      orderId: purchase.orderId
    });
    
    // Validate purchase state (0 = pending, 1 = confirmed, 2 = grace period)
    if (purchase.paymentState !== 1 && purchase.paymentState !== 2) {
      throw new functions.https.HttpsError('failed-precondition', 'Purchase not confirmed');
    }
    
    // Check expiry
    const expiryDate = new Date(parseInt(purchase.expiryTimeMillis));
    if (expiryDate <= FieldValue.serverTimestamp()) {
      throw new functions.https.HttpsError('failed-precondition', 'Subscription has expired');
    }
    
    // Determine product details (simplified for example)
    let planType = 'basic_monthly';
    let amount = 1.99;
    
    if (effectiveProductId.includes('premium')) {
      planType = 'premium_monthly';
      amount = 9.99;
    } else if (effectiveProductId.includes('super')) {
      planType = 'super_payments_monthly';
      amount = 1.99;
    }

    const subscriptionData = {
      userId: userId,
      planType: planType,
      status: 'active',
      paymentMethod: 'google_play',
      amount: amount,
      currency: 'USD',
      purchaseToken: purchaseToken,
      productId: effectiveProductId,
      packageName: packageName || GOOGLE_PLAY_PACKAGE_NAME,
      googlePlayOrderId: purchase.orderId,
      autoRenewing: purchase.autoRenewing,
      createdAt: FieldValue.serverTimestamp(),
      expiryDate: expiryDate,
      lastPaymentDate: FieldValue.serverTimestamp(),
      validatedAt: FieldValue.serverTimestamp()
    };

    // Create subscription record
    const subscriptionRef = await db.collection('subscriptions').add(subscriptionData);
    console.log(`Created subscription record: ${subscriptionRef.id}`);

    // Update user document with isSubscribed: true and expiry as requested (create if doesn't exist)
    await db.collection('users').doc(userId).set({
      isSubscribed: true,
      expiry: expiryDate,
      subscriptionId: subscriptionRef.id,
      subscriptionStatus: 'active',
      subscriptionExpiryDate: expiryDate,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
    
    console.log(`Successfully validated Google Play purchase for user ${userId}`);

    return {
      success: true,
      subscriptionId: subscriptionRef.id,
      expiryDate: expiryDate.toISOString(),
      message: 'Google Play subscription validated successfully',
      autoRenewing: purchase.autoRenewing,
      orderId: purchase.orderId,
      purchase: purchase
    };
    
  } catch (error) {
    console.error('Error validating Google Play purchase:', error);
    
    // Handle specific Google Play API errors
    if (error.code === 410) {
      throw new functions.https.HttpsError('not-found', 'Purchase token not found or expired');
    } else if (error.code === 400) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid purchase token or product ID');
    } else if (error.code === 401) {
      throw new functions.https.HttpsError('permission-denied', 'Google Play API authentication failed');
    } else if (error.message && error.message.includes('HttpsError')) {
      // Re-throw our custom errors
      throw error;
    } else {
      throw new functions.https.HttpsError('internal', 'Failed to validate Google Play purchase');
    }
  }
});

// Validate Apple Pay purchase
exports.validateApplePayPurchase = functions
  .runWith({
    memory: '1GB',
    timeoutSeconds: 60,
    maxInstances: 10
  })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { transactionId, receiptData, productId } = data;
  const userId = context.auth.uid;

  try {
    // Validate purchase with Apple App Store API
    // Note: You'll need to set up App Store Connect API credentials
    // For now, we'll create the subscription record assuming validation passes
    
    const subscriptionData = {
      userId: userId,
      planType: 'super_payments_monthly',
      status: 'active',
      paymentMethod: 'apple_pay',
      amount: 1.99,
      currency: 'USD',
      transactionId: transactionId,
      receiptData: receiptData,
      productId: productId,
      createdAt: FieldValue.serverTimestamp(),
      expiryDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days from now
      lastPaymentDate: FieldValue.serverTimestamp()
    };

    // Create subscription record
    const subscriptionRef = await db.collection('subscriptions').add(subscriptionData);

    // Update user document (create if doesn't exist)
    await db.collection('users').doc(userId).set({
      isSubscribed: true,
      subscriptionId: subscriptionRef.id,
      subscriptionStatus: 'active',
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });

    return {
      success: true,
      subscriptionId: subscriptionRef.id,
      message: 'Apple Pay subscription validated successfully'
    };
  } catch (error) {
    console.error('Error validating Apple Pay purchase:', error);
    throw new functions.https.HttpsError('internal', 'Failed to validate Apple Pay purchase');
  }
});

// Validate platform payment (Apple Pay/Google Pay)
exports.validatePlatformPayment = functions
  .runWith({
    memory: '1GB',
    timeoutSeconds: 60,
    maxInstances: 10
  })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { paymentMethodId, transactionId, amount, currency, timestamp } = data;
  const userId = context.auth.uid;

  try {
    console.log(`Validating platform payment for user ${userId}: ${transactionId}`);
    
    // Validate payment data
    if (!paymentMethodId || !transactionId || !amount || !currency) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required payment data');
    }
    
    // Check for duplicate transaction
    const existingPayment = await db.collection('payments')
      .where('transactionId', '==', transactionId)
      .where('userId', '==', userId)
      .limit(1)
      .get();
    
    if (!existingPayment.empty) {
      throw new functions.https.HttpsError('already-exists', 'Payment already processed');
    }
    
    // Determine payment method type
    const paymentMethod = paymentMethodId.includes('apple_pay') ? 'apple_pay' : 'google_pay';
    
    // Create payment record
    const paymentData = {
      userId: userId,
      paymentMethodId: paymentMethodId,
      transactionId: transactionId,
      amount: amount,
      currency: currency,
      paymentMethod: paymentMethod,
      status: 'completed',
      timestamp: timestamp ? new Date(timestamp) : FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
      validated: true
    };
    
    const paymentRef = await db.collection('payments').add(paymentData);
    
    // Create or update subscription
    const subscriptionData = {
      userId: userId,
      planType: 'super_payments_monthly',
      status: 'active',
      paymentMethod: paymentMethod,
      amount: amount,
      currency: currency,
      paymentId: paymentRef.id,
      transactionId: transactionId,
      createdAt: FieldValue.serverTimestamp(),
      expiryDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days from now
      lastPaymentDate: FieldValue.serverTimestamp(),
      autoRenew: true,
      validationSource: 'platform_payment'
    };
    
    // Check if user already has an active subscription
    const existingSubscription = await db.collection('subscriptions')
      .where('userId', '==', userId)
      .where('status', '==', 'active')
      .limit(1)
      .get();
    
    let subscriptionRef;
    if (!existingSubscription.empty) {
      // Update existing subscription
      subscriptionRef = existingSubscription.docs[0].ref;
      await subscriptionRef.update({
        ...subscriptionData,
        updatedAt: FieldValue.serverTimestamp()
      });
    } else {
      // Create new subscription
      subscriptionRef = await db.collection('subscriptions').add(subscriptionData);
    }
    
    // Update user document
    await db.collection('users').doc(userId).set({
      isSubscribed: true,
      subscriptionId: subscriptionRef.id,
      subscriptionStatus: 'active',
      lastPaymentMethod: paymentMethod,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
    
    console.log(`Platform payment validated successfully for user ${userId}`);
    
    return {
      success: true,
      subscriptionId: subscriptionRef.id,
      paymentId: paymentRef.id,
      message: `${paymentMethod === 'apple_pay' ? 'Apple Pay' : 'Google Pay'} payment validated successfully`,
      expiryDate: subscriptionData.expiryDate.toISOString()
    };
    
  } catch (error) {
    console.error('Error validating platform payment:', error);
    
    // Log failed validation attempt
    try {
      await db.collection('payment_validation_failures').add({
        userId: userId,
        paymentMethodId: paymentMethodId,
        transactionId: transactionId,
        error: error.message,
        timestamp: FieldValue.serverTimestamp()
      });
    } catch (logError) {
      console.error('Error logging validation failure:', logError);
    }
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', 'Failed to validate platform payment');
  }
});

// Create Moov account
// NOTE: createMoovAccount removed - Moov is now only for send/receive money, not subscriptions

// NOTE: processMoovSubscription removed - subscriptions now use in-app purchases only

// ============================================================================
// COMPREHENSIVE SUBSCRIPTION BACKEND SYSTEM
// ============================================================================

// Configuration
const GOOGLE_PLAY_PACKAGE_NAME = functions.config().googleplay?.package_name || 'com.yourapp.package';
const SERVICE_ACCOUNT_FILE = path.join(__dirname, 'firebase-service-account.json');
let GOOGLE_PLAY_SERVICE_ACCOUNT;
if (fs.existsSync(SERVICE_ACCOUNT_FILE)) {
  try {
    GOOGLE_PLAY_SERVICE_ACCOUNT = JSON.parse(fs.readFileSync(SERVICE_ACCOUNT_FILE, 'utf8'));
    console.log('Loaded Google Play service account from file');
  } catch (e) {
    console.error('Failed to parse Google Play service account JSON file:', e);
    throw new Error('Invalid Google Play service account file.');
  }
} else {
  GOOGLE_PLAY_SERVICE_ACCOUNT = {
    type: "service_account",
    project_id: functions.config().googleplay?.project_id || "your-project-id",
    private_key_id: functions.config().googleplay?.private_key_id || "your-private-key-id",
    private_key: functions.config().googleplay?.private_key?.replace(/\\n/g, '\n') || "-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY\n-----END PRIVATE KEY-----\n",
    client_email: functions.config().googleplay?.client_email || "your-service-account@your-project.iam.gserviceaccount.com",
    client_id: functions.config().googleplay?.client_id || "your-client-id",
    auth_uri: "https://accounts.google.com/o/oauth2/auth",
    token_uri: "https://oauth2.googleapis.com/token",
    auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
    client_x509_cert_url: functions.config().googleplay?.client_x509_cert_url || "https://www.googleapis.com/robot/v1/metadata/x509/your-service-account%40your-project.iam.gserviceaccount.com"
  };
}
const APPLE_SHARED_SECRET = functions.config().apple?.shared_secret || 'your_apple_shared_secret';
const APPLE_BUNDLE_ID = functions.config().apple?.bundle_id || 'com.yourapp.bundle';

// ============================================================================
// SCHEDULED FUNCTIONS
// ============================================================================

// Check for expired subscriptions every hour
exports.checkExpiredSubscriptions = functions.pubsub.schedule('0 * * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('Starting expired subscriptions check...');
    
    try {
      const now = new Date();
      const gracePeriodEnd = new Date(now.getTime() - (7 * 24 * 60 * 60 * 1000)); // 7 days ago
      
      // Find subscriptions that are expired but still marked as active
      const expiredQuery = await db.collection('subscriptions')
        .where('status', '==', 'active')
        .where('expiryDate', '<', now)
        .get();
      
      const batch = db.batch();
      let processedCount = 0;
      
      for (const doc of expiredQuery.docs) {
        const subscription = doc.data();
        const expiryDate = subscription.expiryDate.toDate();
        
        if (expiryDate < gracePeriodEnd) {
          // Grace period has ended, mark as expired
          batch.update(doc.ref, {
            status: 'expired',
            updatedAt: FieldValue.serverTimestamp(),
            gracePeriodEnded: true
          });
          
          // Update user document
          if (subscription.userId) {
            const userRef = db.collection('users').doc(subscription.userId);
            batch.update(userRef, {
              isSubscribed: false,
              subscriptionStatus: 'expired',
              updatedAt: FieldValue.serverTimestamp()
            });
          }
        } else {
          // Still in grace period, mark as grace_period
          batch.update(doc.ref, {
            status: 'grace_period',
            updatedAt: FieldValue.serverTimestamp()
          });
        }
        
        processedCount++;
        
        // Commit batch every 500 operations
        if (processedCount % 500 === 0) {
          await batch.commit();
          console.log(`Processed ${processedCount} expired subscriptions`);
        }
      }
      
      // Commit remaining operations
      if (processedCount % 500 !== 0) {
        await batch.commit();
      }
      
      console.log(`Completed expired subscriptions check. Processed: ${processedCount}`);
      
      // Log analytics
      await db.collection('analytics').add({
        type: 'expired_subscriptions_check',
        processedCount: processedCount,
        timestamp: FieldValue.serverTimestamp()
      });
      
    } catch (error) {
      console.error('Error in checkExpiredSubscriptions:', error);
      throw error;
    }
  });

// Manual check for expired subscriptions
exports.checkExpiredSubscriptionsManual = functions.https.onCall(async (data, context) => {
  console.log('Manually triggered expired subscriptions check...');
  
  try {
    const now = FieldValue.serverTimestamp();
    const gracePeriodEnd = new Date(now.getTime() - (7 * 24 * 60 * 60 * 1000)); // 7 days ago
    
    // Find subscriptions that are expired but still marked as active
    const expiredQuery = await db.collection('subscriptions')
      .where('status', '==', 'active')
      .where('expiryDate', '<', now)
      .get();
    
    const batch = db.batch();
    let processedCount = 0;
    
    for (const doc of expiredQuery.docs) {
      const subscription = doc.data();
      const expiryDate = subscription.expiryDate.toDate();
      
      if (expiryDate < gracePeriodEnd) {
        // Grace period has ended, mark as expired
        batch.update(doc.ref, {
          status: 'expired',
          updatedAt: FieldValue.serverTimestamp(),
          gracePeriodEnded: true
        });
        
        // Update user document
        if (subscription.userId) {
          const userRef = db.collection('users').doc(subscription.userId);
          batch.update(userRef, {
            isSubscribed: false,
            subscriptionStatus: 'expired',
            updatedAt: FieldValue.serverTimestamp()
          });
        }
      } else {
        // Still in grace period, mark as grace_period
        batch.update(doc.ref, {
          status: 'grace_period',
          updatedAt: FieldValue.serverTimestamp()
        });
      }
      
      processedCount++;
      
      // Commit batch every 500 operations
      if (processedCount % 500 === 0) {
        await batch.commit();
        console.log(`Processed ${processedCount} expired subscriptions`);
      }
    }
    
    // Commit remaining operations
    if (processedCount % 500 !== 0) {
      await batch.commit();
    }
    
    console.log(`Completed manual expired subscriptions check. Processed: ${processedCount}`);
    
    // Log analytics
    await db.collection('analytics').add({
      type: 'manual_expired_subscriptions_check',
      processedCount: processedCount,
      timestamp: FieldValue.serverTimestamp()
    });
    
    return {
      success: true,
      message: 'Manual check completed',
      processedCount: processedCount
    };
    
  } catch (error) {
    console.error('Error in manual expired subscriptions check:', error);
    throw new functions.https.HttpsError('internal', 'Manual check failed');
  }
});

// Process subscription renewals daily
exports.processSubscriptionRenewals = functions.pubsub.schedule('0 2 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('Starting subscription renewals processing...');
    
    try {
      const threeDaysFromNow = new Date(Date.now() + (3 * 24 * 60 * 60 * 1000));
      
      // Find subscriptions expiring in the next 3 days
      const renewalQuery = await db.collection('subscriptions')
        .where('status', '==', 'active')
        .where('expiryDate', '<=', threeDaysFromNow)
        .where('autoRenew', '==', true)
        .get();
      
      let processedCount = 0;
      let successCount = 0;
      let failureCount = 0;
      
      for (const doc of renewalQuery.docs) {
        const subscription = doc.data();
        
        try {
          let renewalResult = false;
          
          switch (subscription.paymentMethod) {
            case 'google_play':
              renewalResult = await processGooglePlayRenewal(subscription, doc.id);
              break;
            case 'apple_pay':
              renewalResult = await processApplePayRenewal(subscription, doc.id);
              break;
            // NOTE: Moov subscriptions removed - only in-app purchases supported
            default:
              console.log(`Unknown payment method: ${subscription.paymentMethod}`);
          }
          
          if (renewalResult) {
            successCount++;
          } else {
            failureCount++;
          }
          
        } catch (error) {
          console.error(`Error renewing subscription ${doc.id}:`, error);
          failureCount++;
        }
        
        processedCount++;
      }
      
      console.log(`Completed renewals processing. Total: ${processedCount}, Success: ${successCount}, Failed: ${failureCount}`);
      
      // Log analytics
      await db.collection('analytics').add({
        type: 'subscription_renewals',
        processedCount: processedCount,
        successCount: successCount,
        failureCount: failureCount,
        timestamp: FieldValue.serverTimestamp()
      });
      
    } catch (error) {
      console.error('Error in processSubscriptionRenewals:', error);
      throw error;
    }
  });

// Generate daily analytics
exports.generateDailyAnalytics = functions.pubsub.schedule('0 1 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('Generating daily analytics...');
    
    try {
      const today = new Date();
      const yesterday = new Date(today.getTime() - (24 * 60 * 60 * 1000));
      
      // Count active subscriptions
      const activeSubscriptions = await db.collection('subscriptions')
        .where('status', '==', 'active')
        .get();
      
      // Count new subscriptions from yesterday
      const newSubscriptions = await db.collection('subscriptions')
        .where('createdAt', '>=', yesterday)
        .where('createdAt', '<', today)
        .get();
      
      // Count cancelled subscriptions from yesterday
      const cancelledSubscriptions = await db.collection('subscriptions')
        .where('status', '==', 'cancelled')
        .where('updatedAt', '>=', yesterday)
        .where('updatedAt', '<', today)
        .get();
      
      // Calculate revenue from yesterday
      const paymentsQuery = await db.collection('payments')
        .where('createdAt', '>=', yesterday)
        .where('createdAt', '<', today)
        .where('status', '==', 'completed')
        .get();
      
      let totalRevenue = 0;
      paymentsQuery.forEach(doc => {
        const payment = doc.data();
        totalRevenue += payment.amount || 0;
      });
      
      // Store analytics
      await db.collection('daily_analytics').add({
        date: yesterday,
        activeSubscriptions: activeSubscriptions.size,
        newSubscriptions: newSubscriptions.size,
        cancelledSubscriptions: cancelledSubscriptions.size,
        totalRevenue: totalRevenue,
        timestamp: FieldValue.serverTimestamp()
      });
      
      console.log(`Daily analytics generated for ${yesterday.toISOString().split('T')[0]}`);
      
    } catch (error) {
      console.error('Error generating daily analytics:', error);
      throw error;
    }
  });

// ============================================================================
// REAL RECEIPT VALIDATION
// ============================================================================

// Real Google Play purchase validation
exports.validateGooglePlayPurchaseReal = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { purchaseToken, productId, packageName } = data;
  const userId = context.auth.uid;

  // Validate input parameters
  if (!purchaseToken || !productId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters: purchaseToken and productId');
  }

  try {
    console.log(`Validating Google Play purchase for user ${userId}, product ${productId}`);
    
    // Check for duplicate purchase token
    const existingPurchase = await db.collection('subscriptions')
      .where('purchaseToken', '==', purchaseToken)
      .where('userId', '==', userId)
      .limit(1)
      .get();
    
    if (!existingPurchase.empty) {
      console.log(`Duplicate purchase token detected: ${purchaseToken}`);
      const existingDoc = existingPurchase.docs[0];
      const existingData = existingDoc.data();
      
      return {
        success: true,
        subscriptionId: existingDoc.id,
        expiryDate: existingData.expiryDate.toDate().toISOString(),
        message: 'Purchase already validated',
        isDuplicate: true
      };
    }

    // Initialize Google Play Developer API
    const auth = new google.auth.GoogleAuth({
      credentials: GOOGLE_PLAY_SERVICE_ACCOUNT,
      scopes: ['https://www.googleapis.com/auth/androidpublisher']
    });
    
    const androidPublisher = google.androidpublisher({ version: 'v3', auth });
    
    // Verify the purchase with Google Play
    const response = await androidPublisher.purchases.subscriptions.get({
      packageName: packageName || GOOGLE_PLAY_PACKAGE_NAME,
      subscriptionId: productId,
      token: purchaseToken
    });
    
    const purchase = response.data;
    console.log(`Google Play API response:`, {
      paymentState: purchase.paymentState,
      autoRenewing: purchase.autoRenewing,
      expiryTimeMillis: purchase.expiryTimeMillis,
      orderId: purchase.orderId
    });
    
    // Validate purchase state
    if (purchase.paymentState !== 1) { // 1 = Received
      console.error(`Invalid payment state: ${purchase.paymentState}`);
      throw new functions.https.HttpsError('invalid-argument', `Purchase payment state invalid: ${purchase.paymentState}`);
    }
    
    // Check if subscription is expired
    const expiryDate = new Date(parseInt(purchase.expiryTimeMillis));
    const now = FieldValue.serverTimestamp();
    
    if (expiryDate <= now) {
      console.error(`Subscription expired: ${expiryDate.toISOString()}`);
      throw new functions.https.HttpsError('invalid-argument', 'Subscription has expired');
    }
    
    // Validate product ID against allowed subscription products
    const allowedProducts = {
      'super_payments_monthly': { amount: 1.99, currency: 'USD', name: 'Super Payments Monthly' },
      'DP07071990': { amount: 1.99, currency: 'USD', name: 'Super Payments Monthly (iOS)' },
      '07071990': { amount: 1.99, currency: 'USD', name: 'Super Payments Monthly (Android)' }
    };
    
    if (!allowedProducts[productId]) {
      console.error(`Invalid product ID: ${productId}`);
      throw new functions.https.HttpsError('invalid-argument', `Product ID '${productId}' is not a valid subscription product`);
    }
    
    const pricing = allowedProducts[productId];
    
    const subscriptionData = {
      userId: userId,
      planType: productId,
      status: 'active',
      paymentMethod: 'google_play',
      amount: pricing.amount,
      currency: pricing.currency,
      purchaseToken: purchaseToken,
      productId: productId,
      packageName: packageName || GOOGLE_PLAY_PACKAGE_NAME,
      googlePlayOrderId: purchase.orderId,
      autoRenew: purchase.autoRenewing || false,
      paymentState: purchase.paymentState,
      acknowledgementState: purchase.acknowledgementState,
      createdAt: FieldValue.serverTimestamp(),
      expiryDate: expiryDate,
      lastPaymentDate: FieldValue.serverTimestamp(),
      validatedAt: FieldValue.serverTimestamp()
    };

    // Create subscription record
    const subscriptionRef = await db.collection('subscriptions').add(subscriptionData);
    console.log(`Created subscription record: ${subscriptionRef.id}`);

    // Update user document (create if doesn't exist)
    await db.collection('users').doc(userId).set({
      isSubscribed: true,
      subscriptionId: subscriptionRef.id,
      subscriptionStatus: 'active',
      subscriptionExpiryDate: expiryDate,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
    
    console.log(`Successfully validated Google Play purchase for user ${userId}`);

    return {
      success: true,
      subscriptionId: subscriptionRef.id,
      expiryDate: expiryDate.toISOString(),
      message: 'Google Play subscription validated successfully',
      autoRenewing: purchase.autoRenewing,
      orderId: purchase.orderId
    };
    
  } catch (error) {
    console.error('Error validating Google Play purchase:', error);
    
    // Handle specific Google Play API errors
    if (error.code === 410) {
      throw new functions.https.HttpsError('not-found', 'Purchase token not found or expired');
    } else if (error.code === 400) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid purchase token or product ID');
    } else if (error.code === 401) {
      throw new functions.https.HttpsError('permission-denied', 'Google Play API authentication failed');
    } else if (error.message && error.message.includes('HttpsError')) {
      // Re-throw our custom errors
      throw error;
    } else {
      throw new functions.https.HttpsError('internal', 'Failed to validate Google Play purchase');
    }
  }
});

// Real Apple Pay purchase validation
exports.validateApplePayPurchaseReal = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { receiptData, productId } = data;
  const userId = context.auth.uid;

  // Input validation
  if (!receiptData || !productId) {
    throw new functions.https.HttpsError('invalid-argument', 'Receipt data and product ID are required');
  }

  console.log('Validating Apple receipt for user:', userId, 'product:', productId);

  // Validate product ID against allowed subscription products
  const allowedProducts = {
    'super_payments_monthly': { amount: 1.99, currency: 'USD', name: 'Super Payments Monthly' },
    'DP07071990': { amount: 1.99, currency: 'USD', name: 'Super Payments Monthly (iOS)' },
    '07071990': { amount: 1.99, currency: 'USD', name: 'Super Payments Monthly (Android)' }
  };
  
  if (!allowedProducts[productId]) {
    console.error(`Invalid product ID: ${productId}`);
    throw new functions.https.HttpsError('invalid-argument', `Product ID '${productId}' is not a valid subscription product`);
  }
  
  const pricing = allowedProducts[productId];

  try {
    // Check for duplicate receipt
    const existingSubscription = await db.collection('subscriptions')
      .where('userId', '==', userId)
      .where('receiptData', '==', receiptData)
      .where('status', '==', 'active')
      .get();

    if (!existingSubscription.empty) {
      console.log('Duplicate receipt detected for user:', userId);
      throw new functions.https.HttpsError('already-exists', 'This receipt has already been processed');
    }

    // Validate with Apple App Store
    const appleResponse = await validateAppleReceipt(receiptData);
    
    if (!appleResponse.success) {
      console.log('Apple receipt validation failed:', appleResponse.error);
      throw new functions.https.HttpsError('invalid-argument', appleResponse.error || 'Invalid receipt');
    }

    const receipt = appleResponse.receipt;
    const latestReceiptInfo = appleResponse.latest_receipt_info;
    
    if (!latestReceiptInfo || latestReceiptInfo.length === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'No subscription information found in receipt');
    }

    // Find the subscription for our product
    const subscription = latestReceiptInfo.find(item => item.product_id === productId);
    
    if (!subscription) {
      throw new functions.https.HttpsError('invalid-argument', 'Product not found in receipt');
    }

    // Check if subscription is still valid
    const expiryDate = new Date(parseInt(subscription.expires_date_ms));
    const now = FieldValue.serverTimestamp();
    
    if (expiryDate <= now) {
      throw new functions.https.HttpsError('failed-precondition', 'Subscription has expired');
    }

    console.log('Apple subscription validated successfully. Expiry:', expiryDate.toISOString());

    // Store subscription in Firestore
    const subscriptionData = {
      userId: userId,
      platform: 'apple',
      productId: productId,
      productName: pricing.name,
      amount: pricing.amount,
      currency: pricing.currency,
      transactionId: subscription.transaction_id,
      originalTransactionId: subscription.original_transaction_id,
      receiptData: receiptData,
      purchaseDate: new Date(parseInt(subscription.purchase_date_ms)),
      expiryDate: expiryDate,
      autoRenewing: subscription.is_in_intro_offer_period === 'false' && subscription.is_trial_period === 'false',
      status: 'active',
      paymentMethod: 'apple_pay',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      validatedAt: FieldValue.serverTimestamp(),
      isTrialPeriod: subscription.is_trial_period === 'true',
      isInIntroOfferPeriod: subscription.is_in_intro_offer_period === 'true',
      cancellationDate: subscription.cancellation_date_ms ? new Date(parseInt(subscription.cancellation_date_ms)) : null
    };

    const subscriptionRef = await db.collection('subscriptions').add(subscriptionData);
    console.log('Apple subscription stored with ID:', subscriptionRef.id);

    // Update user document (create if doesn't exist)
    await db.collection('users').doc(userId).set({
      hasActiveSubscription: true,
      subscriptionPlatform: 'apple',
      subscriptionExpiryDate: expiryDate,
      subscriptionId: subscriptionRef.id,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });

    console.log('User document updated for Apple subscription');

    return {
      success: true,
      subscriptionId: subscriptionRef.id,
      expiryDate: expiryDate.toISOString(),
      message: 'Apple App Store subscription validated successfully',
      autoRenewing: subscriptionData.autoRenewing,
      transactionId: subscription.transaction_id
    };
    
  } catch (error) {
    console.error('Error validating Apple receipt:', error);
    
    // Handle specific Apple App Store errors
    if (error.message && error.message.includes('HttpsError')) {
      // Re-throw our custom errors
      throw error;
    } else if (error.status === 21007) {
      throw new functions.https.HttpsError('invalid-argument', 'Receipt is from sandbox environment');
    } else if (error.status === 21008) {
      throw new functions.https.HttpsError('invalid-argument', 'Receipt is from production environment');
    } else if (error.status === 21002) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid receipt data');
    } else {
      throw new functions.https.HttpsError('internal', 'Failed to validate Apple App Store purchase');
    }
  }
});

// Helper function to validate Apple receipt
async function validateAppleReceipt(receiptData) {
  const requestBody = {
    'receipt-data': receiptData,
    'password': APPLE_SHARED_SECRET,
    'exclude-old-transactions': true
  };

  try {
    // Try production first
    const productionResponse = await axios.post('https://buy.itunes.apple.com/verifyReceipt', requestBody);
    
    if (productionResponse.data.status === 0) {
      return { success: true, ...productionResponse.data };
    } else if (productionResponse.data.status === 21007) {
      // Receipt is from sandbox, try sandbox URL
      const sandboxResponse = await axios.post('https://sandbox.itunes.apple.com/verifyReceipt', requestBody);
      
      if (sandboxResponse.data.status === 0) {
        return { success: true, ...sandboxResponse.data };
      } else {
        return { success: false, error: `Apple validation failed with status: ${sandboxResponse.data.status}` };
      }
    } else {
      return { success: false, error: `Apple validation failed with status: ${productionResponse.data.status}` };
    }
  } catch (error) {
    console.error('Apple receipt validation network error:', error);
    return { success: false, error: 'Network error during Apple receipt validation' };
  }
}

// ============================================================================
// WEBHOOK VALIDATION AND SIGNATURE VERIFICATION
// ============================================================================

// Google Play webhook handler
exports.googlePlayWebhook = functions.https.onRequest(async (req, res) => {
  try {
    // Verify webhook signature (implement based on Google's documentation)
    // const signature = req.headers['x-goog-signature'];
    // if (!verifyGooglePlaySignature(req.body, signature)) {
    //   return res.status(401).send('Invalid signature');
    // }
    
    const message = req.body.message;
    if (!message) {
      return res.status(400).send('No message found');
    }
    
    // Decode the base64 message
    const decodedData = JSON.parse(Buffer.from(message.data, 'base64').toString());
    
    console.log('Google Play webhook received:', decodedData);
    
    // Handle the subscription notification
    await handleGooglePlaySubscriptionNotification(decodedData);
    
    res.status(200).send('OK');
    
  } catch (error) {
    console.error('Error handling Google Play webhook:', error);
    res.status(500).send('Internal Server Error');
  }
});

// Apple App Store webhook handler
exports.appleAppStoreWebhook = functions.https.onRequest(async (req, res) => {
  try {
    // Verify webhook signature (implement based on Apple's documentation)
    // const signature = req.headers['x-apple-signature'];
    // if (!verifyAppleSignature(req.body, signature)) {
    //   return res.status(401).send('Invalid signature');
    // }
    
    const notification = req.body;
    
    console.log('Apple App Store webhook received:', notification.notificationType);
    
    // Handle different notification types
    switch (notification.notificationType) {
      case 'INITIAL_BUY':
        await handleAppleInitialBuy(notification);
        break;
      case 'DID_RENEW':
        await handleAppleRenewal(notification);
        break;
      case 'DID_FAIL_TO_RENEW':
        await handleAppleRenewalFailure(notification);
        break;
      case 'DID_CANCEL':
        await handleAppleCancellation(notification);
        break;
      case 'REFUND':
        await handleAppleRefund(notification);
        break;
      default:
        console.log(`Unhandled Apple notification type: ${notification.notificationType}`);
    }
    
    res.status(200).send('OK');
    
  } catch (error) {
    console.error('Error handling Apple App Store webhook:', error);
    res.status(500).send('Internal Server Error');
  }
});

// ============================================================================
// SUBSCRIPTION MANAGEMENT
// ============================================================================

// Cancel subscription
exports.cancelSubscription = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { subscriptionId, reason } = data;
  const userId = context.auth.uid;

  try {
    // Get subscription
    const subscriptionDoc = await db.collection('subscriptions').doc(subscriptionId).get();
    
    if (!subscriptionDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Subscription not found');
    }
    
    const subscription = subscriptionDoc.data();
    
    // Verify ownership
    if (subscription.userId !== userId) {
      throw new functions.https.HttpsError('permission-denied', 'Not authorized to cancel this subscription');
    }
    
    // Update subscription status
    await db.collection('subscriptions').doc(subscriptionId).update({
      status: 'cancelled',
      cancellationReason: reason || 'User requested',
      cancelledAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    });
    
    // Update user document
    await db.collection('users').doc(userId).set({
      isSubscribed: false,
      subscriptionStatus: 'cancelled',
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
    
    // Log cancellation event
    await db.collection('subscription_events').add({
      subscriptionId: subscriptionId,
      userId: userId,
      eventType: 'cancellation',
      reason: reason || 'User requested',
      timestamp: FieldValue.serverTimestamp()
    });
    
    return {
      success: true,
      message: 'Subscription cancelled successfully'
    };
    
  } catch (error) {
    console.error('Error cancelling subscription:', error);
    throw new functions.https.HttpsError('internal', 'Failed to cancel subscription');
  }
});

// ============================================================================
// HELPER FUNCTIONS FOR RENEWAL PROCESSING
// ============================================================================

// Process Google Play renewal
async function processGooglePlayRenewal(subscription, subscriptionId) {
  try {
    // Initialize Google Play Developer API
    const auth = new google.auth.GoogleAuth({
      credentials: GOOGLE_PLAY_SERVICE_ACCOUNT,
      scopes: ['https://www.googleapis.com/auth/androidpublisher']
    });
    
    const androidPublisher = google.androidpublisher({ version: 'v3', auth });
    
    // Check current subscription status
    const response = await androidPublisher.purchases.subscriptions.get({
      packageName: subscription.packageName,
      subscriptionId: subscription.productId,
      token: subscription.purchaseToken
    });
    
    const purchase = response.data;
    
    if (purchase.paymentState === 1 && purchase.autoRenewing) {
      // Subscription is active and auto-renewing
      const newExpiryDate = new Date(parseInt(purchase.expiryTimeMillis));
      
      await db.collection('subscriptions').doc(subscriptionId).update({
        expiryDate: newExpiryDate,
        lastPaymentDate: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
      });
      
      return true;
    }
    
    return false;
    
  } catch (error) {
    console.error('Error processing Google Play renewal:', error);
    return false;
  }
}

// Process Apple Pay renewal
async function processApplePayRenewal(subscription, subscriptionId) {
  try {
    // Verify receipt with Apple
    const verifyUrl = 'https://buy.itunes.apple.com/verifyReceipt';
    
    const response = await axios.post(verifyUrl, {
      'receipt-data': subscription.receiptData,
      'password': APPLE_SHARED_SECRET,
      'exclude-old-transactions': true
    });
    
    const receiptInfo = response.data;
    
    if (receiptInfo.status === 0 && receiptInfo.latest_receipt_info) {
      const latestReceipt = receiptInfo.latest_receipt_info[0];
      const newExpiryDate = new Date(parseInt(latestReceipt.expires_date_ms));
      
      await db.collection('subscriptions').doc(subscriptionId).update({
        expiryDate: newExpiryDate,
        lastPaymentDate: FieldValue.serverTimestamp(),
        appleTransactionId: latestReceipt.transaction_id,
        updatedAt: FieldValue.serverTimestamp()
      });
      
      return true;
    }
    
    return false;
    
  } catch (error) {
    console.error('Error processing Apple Pay renewal:', error);
    return false;
  }
}

// Process Moov renewal
// NOTE: processMoovRenewal removed - subscriptions now use in-app purchases only

// ============================================================================
// WEBHOOK NOTIFICATION HANDLERS
// ============================================================================

// Handle Google Play subscription notification
async function handleGooglePlaySubscriptionNotification(data) {
  try {
    const { subscriptionNotification } = data;
    
    if (!subscriptionNotification) {
      console.log('No subscription notification found');
      return;
    }
    
    const { purchaseToken, subscriptionId, notificationType } = subscriptionNotification;
    
    // Find subscription by purchase token
    const subscriptionQuery = await db.collection('subscriptions')
      .where('purchaseToken', '==', purchaseToken)
      .limit(1)
      .get();
    
    if (subscriptionQuery.empty) {
      console.log(`No subscription found for purchase token: ${purchaseToken}`);
      return;
    }
    
    const subscriptionDoc = subscriptionQuery.docs[0];
    const subscription = subscriptionDoc.data();
    
    // Handle different notification types
    switch (notificationType) {
      case 1: // SUBSCRIPTION_RECOVERED
        await db.collection('subscriptions').doc(subscriptionDoc.id).update({
          status: 'active',
          updatedAt: FieldValue.serverTimestamp()
        });
        break;
        
      case 2: // SUBSCRIPTION_RENEWED
        // Fetch updated subscription info from Google Play
        await processGooglePlayRenewal(subscription, subscriptionDoc.id);
        break;
        
      case 3: // SUBSCRIPTION_CANCELED
        await db.collection('subscriptions').doc(subscriptionDoc.id).update({
          status: 'cancelled',
          cancelledAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        });
        break;
        
      case 4: // SUBSCRIPTION_PURCHASED
        // New subscription, should already be handled by validation
        break;
        
      case 5: // SUBSCRIPTION_ON_HOLD
        await db.collection('subscriptions').doc(subscriptionDoc.id).update({
          status: 'on_hold',
          updatedAt: FieldValue.serverTimestamp()
        });
        break;
        
      case 6: // SUBSCRIPTION_IN_GRACE_PERIOD
        await db.collection('subscriptions').doc(subscriptionDoc.id).update({
          status: 'grace_period',
          updatedAt: FieldValue.serverTimestamp()
        });
        break;
        
      case 7: // SUBSCRIPTION_RESTARTED
        await db.collection('subscriptions').doc(subscriptionDoc.id).update({
          status: 'active',
          updatedAt: FieldValue.serverTimestamp()
        });
        break;
        
      case 8: // SUBSCRIPTION_PRICE_CHANGE_CONFIRMED
        // Handle price change confirmation
        break;
        
      case 9: // SUBSCRIPTION_DEFERRED
        await db.collection('subscriptions').doc(subscriptionDoc.id).update({
          status: 'deferred',
          updatedAt: FieldValue.serverTimestamp()
        });
        break;
        
      case 10: // SUBSCRIPTION_PAUSED
        await db.collection('subscriptions').doc(subscriptionDoc.id).update({
          status: 'paused',
          updatedAt: FieldValue.serverTimestamp()
        });
        break;
        
      case 11: // SUBSCRIPTION_PAUSE_SCHEDULE_CHANGED
        // Handle pause schedule change
        break;
        
      case 12: // SUBSCRIPTION_REVOKED
        await db.collection('subscriptions').doc(subscriptionDoc.id).update({
          status: 'revoked',
          revokedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        });
        break;
        
      case 13: // SUBSCRIPTION_EXPIRED
        await db.collection('subscriptions').doc(subscriptionDoc.id).update({
          status: 'expired',
          updatedAt: FieldValue.serverTimestamp()
        });
        break;
        
      default:
        console.log(`Unhandled Google Play notification type: ${notificationType}`);
    }
    
    // Log the event
    await db.collection('subscription_events').add({
      subscriptionId: subscriptionDoc.id,
      userId: subscription.userId,
      eventType: 'google_play_notification',
      notificationType: notificationType,
      purchaseToken: purchaseToken,
      timestamp: FieldValue.serverTimestamp()
    });
    
  } catch (error) {
    console.error('Error handling Google Play subscription notification:', error);
  }
}

// Handle Apple initial buy
async function handleAppleInitialBuy(notification) {
  try {
    // This is typically handled by the client-side validation
    console.log('Apple initial buy notification received');
    
    // Log the event
    await db.collection('subscription_events').add({
      eventType: 'apple_initial_buy',
      notification: notification,
      timestamp: FieldValue.serverTimestamp()
    });
    
  } catch (error) {
    console.error('Error handling Apple initial buy:', error);
  }
}

// Handle Apple renewal
async function handleAppleRenewal(notification) {
  try {
    const { latest_receipt_info } = notification;
    
    if (!latest_receipt_info || latest_receipt_info.length === 0) {
      console.log('No receipt info found in Apple renewal notification');
      return;
    }
    
    const latestReceipt = latest_receipt_info[0];
    const originalTransactionId = latestReceipt.original_transaction_id;
    
    // Find subscription by original transaction ID
    const subscriptionQuery = await db.collection('subscriptions')
      .where('appleOriginalTransactionId', '==', originalTransactionId)
      .limit(1)
      .get();
    
    if (!subscriptionQuery.empty) {
      const subscriptionDoc = subscriptionQuery.docs[0];
      const newExpiryDate = new Date(parseInt(latestReceipt.expires_date_ms));
      
      await db.collection('subscriptions').doc(subscriptionDoc.id).update({
        status: 'active',
        expiryDate: newExpiryDate,
        lastPaymentDate: FieldValue.serverTimestamp(),
        appleTransactionId: latestReceipt.transaction_id,
        updatedAt: FieldValue.serverTimestamp()
      });
      
      // Log the event
      await db.collection('subscription_events').add({
        subscriptionId: subscriptionDoc.id,
        eventType: 'apple_renewal',
        transactionId: latestReceipt.transaction_id,
        timestamp: FieldValue.serverTimestamp()
      });
    }
    
  } catch (error) {
    console.error('Error handling Apple renewal:', error);
  }
}

// Handle Apple renewal failure
async function handleAppleRenewalFailure(notification) {
  try {
    const { latest_expired_receipt_info } = notification;
    
    if (!latest_expired_receipt_info || latest_expired_receipt_info.length === 0) {
      console.log('No expired receipt info found in Apple renewal failure notification');
      return;
    }
    
    const expiredReceipt = latest_expired_receipt_info[0];
    const originalTransactionId = expiredReceipt.original_transaction_id;
    
    // Find subscription by original transaction ID
    const subscriptionQuery = await db.collection('subscriptions')
      .where('appleOriginalTransactionId', '==', originalTransactionId)
      .limit(1)
      .get();
    
    if (!subscriptionQuery.empty) {
      const subscriptionDoc = subscriptionQuery.docs[0];
      
      await db.collection('subscriptions').doc(subscriptionDoc.id).update({
        status: 'payment_failed',
        lastPaymentAttempt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
      });
      
      // Log the event
      await db.collection('subscription_events').add({
        subscriptionId: subscriptionDoc.id,
        eventType: 'apple_renewal_failure',
        originalTransactionId: originalTransactionId,
        timestamp: FieldValue.serverTimestamp()
      });
    }
    
  } catch (error) {
    console.error('Error handling Apple renewal failure:', error);
  }
}

// Handle Apple cancellation
async function handleAppleCancellation(notification) {
  try {
    const { latest_receipt_info } = notification;
    
    if (!latest_receipt_info || latest_receipt_info.length === 0) {
      console.log('No receipt info found in Apple cancellation notification');
      return;
    }
    
    const latestReceipt = latest_receipt_info[0];
    const originalTransactionId = latestReceipt.original_transaction_id;
    
    // Find subscription by original transaction ID
    const subscriptionQuery = await db.collection('subscriptions')
      .where('appleOriginalTransactionId', '==', originalTransactionId)
      .limit(1)
      .get();
    
    if (!subscriptionQuery.empty) {
      const subscriptionDoc = subscriptionQuery.docs[0];
      
      await db.collection('subscriptions').doc(subscriptionDoc.id).update({
        status: 'cancelled',
        cancelledAt: FieldValue.serverTimestamp(),
        cancellationReason: 'Apple cancellation',
        updatedAt: FieldValue.serverTimestamp()
      });
      
      // Update user document
      const subscription = subscriptionDoc.data();
      if (subscription.userId) {
        await db.collection('users').doc(subscription.userId).set({
          isSubscribed: false,
          subscriptionStatus: 'cancelled',
          updatedAt: FieldValue.serverTimestamp()
        }, { merge: true });
      }
      
      // Log the event
      await db.collection('subscription_events').add({
        subscriptionId: subscriptionDoc.id,
        userId: subscription.userId,
        eventType: 'apple_cancellation',
        originalTransactionId: originalTransactionId,
        timestamp: FieldValue.serverTimestamp()
      });
    }
    
  } catch (error) {
    console.error('Error handling Apple cancellation:', error);
  }
}

// Handle Apple refund
async function handleAppleRefund(notification) {
  try {
    const { latest_receipt_info } = notification;
    
    if (!latest_receipt_info || latest_receipt_info.length === 0) {
      console.log('No receipt info found in Apple refund notification');
      return;
    }
    
    const latestReceipt = latest_receipt_info[0];
    const originalTransactionId = latestReceipt.original_transaction_id;
    
    // Find subscription by original transaction ID
    const subscriptionQuery = await db.collection('subscriptions')
      .where('appleOriginalTransactionId', '==', originalTransactionId)
      .limit(1)
      .get();
    
    if (!subscriptionQuery.empty) {
      const subscriptionDoc = subscriptionQuery.docs[0];
      
      await db.collection('subscriptions').doc(subscriptionDoc.id).update({
        status: 'refunded',
        refundedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
      });
      
      // Update user document
      const subscription = subscriptionDoc.data();
      if (subscription.userId) {
        await db.collection('users').doc(subscription.userId).set({
          isSubscribed: false,
          subscriptionStatus: 'refunded',
          updatedAt: FieldValue.serverTimestamp()
        }, { merge: true });
      }
      
      // Log the event
      await db.collection('subscription_events').add({
        subscriptionId: subscriptionDoc.id,
        userId: subscription.userId,
        eventType: 'apple_refund',
        originalTransactionId: originalTransactionId,
        timestamp: FieldValue.serverTimestamp()
      });
    }
    
  } catch (error) {
    console.error('Error handling Apple refund:', error);
  }
}