const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

// Moov configuration
const MOOV_CONFIG = {
  baseURL: functions.config().moov?.base_url || 'https://api.moov.io',
  publicKey: functions.config().moov?.public_key,
  privateKey: functions.config().moov?.private_key,
  platformAccountId: functions.config().moov?.platform_account_id
};

// Validate required configuration
function validateMoovConfig() {
  if (!MOOV_CONFIG.publicKey || !MOOV_CONFIG.privateKey) {
    throw new Error('Moov API keys are not configured. Please set moov.public_key and moov.private_key in Firebase config.');
  }
}

// Create Basic Auth header for Moov API
function createBasicAuthHeader() {
  validateMoovConfig();
  const credentials = Buffer.from(`${MOOV_CONFIG.publicKey}:${MOOV_CONFIG.privateKey}`).toString('base64');
  return `Basic ${credentials}`;
}

// Get headers for Moov API requests
function moovHeaders() {
  return {
    'Authorization': createBasicAuthHeader(),
    'Content-Type': 'application/json',
    'X-Platform-Account-ID': MOOV_CONFIG.platformAccountId || ''
  };
}

// Shared Firestore
const db = admin.firestore();

// Utility: ensure a user's Moov account is stored on their user doc
async function saveUserMoovAccountId(uid, accountID, status) {
  await db.collection('users').doc(uid).set({
    moovAccountId: accountID,
    moovAccountStatus: status || 'unknown',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

// Create Moov account (individual) for the authenticated user
exports.createMoovAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  const uid = context.auth.uid;

  const { email, firstName, lastName, phone } = data || {};
  if (!email || !firstName || !lastName) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields: email, firstName, lastName');
  }

  try {
    // Create account using API key authentication
    const createResp = await axios.post(`${MOOV_CONFIG.baseURL}/accounts`, {
      accountType: 'individual',
      profile: {
        individual: {
          name: { firstName, lastName },
          email,
          phone: phone ? { number: phone, countryCode: '1' } : undefined,
        },
      },
      foreignId: uid,
    }, { headers: moovHeaders(), timeout: 15000 });

    const account = createResp.data;

    // Request capabilities (transfers, send-funds, wallet)
    try {
      await axios.post(`${MOOV_CONFIG.baseURL}/accounts/${account.accountID}/capabilities`, {
        capabilities: ['transfers', 'send-funds', 'wallet'],
      }, { headers: moovHeaders(), timeout: 15000 });
    } catch (e) {
      console.warn('[moov_api] capabilities request failed:', e?.response?.data || e.message);
    }

    // Create wallet for the account
    let walletId = null;
    try {
      const walletResp = await axios.post(`${MOOV_CONFIG.baseURL}/accounts/${account.accountID}/wallets`, {
        walletID: `wallet_${account.accountID}`,
      }, { headers: moovHeaders(), timeout: 15000 });
      walletId = walletResp.data.walletID;
    } catch (e) {
      console.warn('[moov_api] wallet creation failed:', e?.response?.data || e.message);
    }

    // Save to Firestore
    await saveUserMoovAccountId(uid, account.accountID, account.verification?.status);

    return {
      success: true,
      accountID: account.accountID,
      walletID: walletId,
      status: account.verification?.status || 'unverified',
    };
  } catch (error) {
    console.error('[moov_api] createMoovAccount error:', error?.response?.data || error.message);
    throw new functions.https.HttpsError('internal', 'Failed to create Moov account');
  }
});

// Get or create Moov account for user
exports.getOrCreateMoovAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  const uid = context.auth.uid;

  // Check if user already has a Moov account
  const userDoc = await db.collection('users').doc(uid).get();
  if (userDoc.exists && userDoc.data()?.moovAccountId) {
    return { success: true, accountID: userDoc.data().moovAccountId, exists: true };
  }

  // Create new account if none exists
  return exports.createMoovAccount(data, context);
});

// Get Moov account details
exports.getMoovAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  const uid = context.auth.uid;
  const { accountId } = data || {};

  let accId = accountId;
  if (!accId) {
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists || !userDoc.data()?.moovAccountId) {
      throw new functions.https.HttpsError('failed-precondition', 'No Moov account on file for user');
    }
    accId = userDoc.data().moovAccountId;
  }

  try {
    const resp = await axios.get(`${MOOV_CONFIG.baseURL}/accounts/${accId}`, {
      headers: moovHeaders(),
      timeout: 10000,
    });
    return { success: true, data: resp.data };
  } catch (err) {
    console.error('[moov_api] getMoovAccount failed:', err?.response?.data || err.message);
    throw new functions.https.HttpsError('internal', 'Failed to fetch account');
  }
});

// List payment methods
exports.listPaymentMethods = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  const uid = context.auth.uid;
  const { accountId } = data || {};

  let accId = accountId;
  if (!accId) {
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists || !userDoc.data()?.moovAccountId) {
      throw new functions.https.HttpsError('failed-precondition', 'No Moov account on file for user');
    }
    accId = userDoc.data().moovAccountId;
  }

  try {
    const resp = await axios.get(`${MOOV_CONFIG.baseURL}/accounts/${accId}/payment-methods`, {
      headers: moovHeaders(),
      timeout: 10000,
    });
    return { success: true, data: resp.data };
  } catch (err) {
    console.error('[moov_api] listPaymentMethods failed:', err?.response?.data || err.message);
    throw new functions.https.HttpsError('internal', 'Failed to list payment methods');
  }
});

// Delete payment method
exports.deletePaymentMethod = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { accountId, paymentMethodId } = data || {};
  if (!accountId || !paymentMethodId) {
    throw new functions.https.HttpsError('invalid-argument', 'accountId and paymentMethodId are required');
  }

  try {
    await axios.delete(`${MOOV_CONFIG.baseURL}/accounts/${accountId}/payment-methods/${paymentMethodId}`, {
      headers: moovHeaders(),
      timeout: 10000,
    });
    return { success: true };
  } catch (err) {
    console.error('[moov_api] deletePaymentMethod failed:', err?.response?.data || err.message);
    throw new functions.https.HttpsError('internal', 'Failed to delete payment method');
  }
});

// Create P2P transfer between two Moov wallets
exports.createP2PTransfer = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  if (!MOOV_CONFIG.platformAccountId) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Moov platform account id is not configured. Set functions config moov.platform_account_id.'
    );
  }

  const { senderWalletId, recipientWalletId, senderAccountId, recipientAccountId, amount, currency = 'USD', description } = data || {};
  
  // Support both wallet IDs (preferred) and account IDs (fallback)
  let sourceWalletId = senderWalletId;
  let destWalletId = recipientWalletId;
  
  // If wallet IDs not provided, try to get them from account IDs
  if (!sourceWalletId && senderAccountId) {
    try {
      const senderDoc = await db.collection('users').where('moovAccountId', '==', senderAccountId).limit(1).get();
      if (!senderDoc.empty) {
        sourceWalletId = senderDoc.docs[0].data().moovWalletId;
      }
    } catch (e) {
      console.warn('[moov_api] Failed to get sender wallet ID:', e.message);
    }
  }
  
  if (!destWalletId && recipientAccountId) {
    try {
      const recipientDoc = await db.collection('users').where('moovAccountId', '==', recipientAccountId).limit(1).get();
      if (!recipientDoc.empty) {
        destWalletId = recipientDoc.docs[0].data().moovWalletId;
      }
    } catch (e) {
      console.warn('[moov_api] Failed to get recipient wallet ID:', e.message);
    }
  }

  if (!sourceWalletId || !destWalletId || !amount) {
    throw new functions.https.HttpsError('invalid-argument', 'senderWalletId, recipientWalletId, and amount are required. Ensure users have wallets created.');
  }

  try {
    // Generate unique idempotency key for transfer
    const idempotencyKey = `transfer_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    const resp = await axios.post(`${MOOV_CONFIG.baseURL}/transfers`, {
      source: { wallet: { walletID: sourceWalletId } },
      destination: { wallet: { walletID: destWalletId } },
      amount: { currency, value: Math.round(Number(amount) * 100) },
      description: description || 'P2P Transfer',
      metadata: { transferType: 'p2p', userId: context.auth.uid, ts: new Date().toISOString() },
    }, {
      headers: { ...moovHeaders(), 'Idempotency-Key': idempotencyKey },
      timeout: 15000,
    });

    const transfer = resp.data;

    // Persist minimal transaction record
    await db.collection('transactions').add({
      userId: context.auth.uid,
      transferId: transfer.transferID,
      senderAccountId,
      recipientAccountId,
      amount: transfer.amount?.value,
      currency: transfer.amount?.currency || currency,
      status: transfer.status,
      description: description || 'P2P Transfer',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, transferId: transfer.transferID, status: transfer.status, data: transfer };
  } catch (err) {
    console.error('[moov_api] createP2PTransfer failed:', err?.response?.data || err.message);
    throw new functions.https.HttpsError('internal', 'Failed to create transfer');
  }
});

// Verify bank account details with Moov
exports.verifyBankAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { accountNumber, routingNumber, accountType, accountHolderName } = data || {};
  if (!accountNumber || !routingNumber || !accountType || !accountHolderName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'accountNumber, routingNumber, accountType, and accountHolderName are required'
    );
  }

  try {
    const resp = await axios.post(
      `${MOOV_CONFIG.baseURL}/bank-accounts/verify`,
      {
        account: {
          accountNumber,
          routingNumber,
          accountType: String(accountType).toLowerCase(),
        },
        accountHolder: {
          name: accountHolderName,
        },
      },
      { headers: moovHeaders(), timeout: 15000 }
    );

    const body = resp.data || {};

    return {
      success: true,
      status: 'verified',
      moovAccountId: body.accountID || body.accountId || null,
      data: body,
    };
  } catch (err) {
    console.error('[moov_api] verifyBankAccount failed:', err?.response?.data || err.message);

    // Return structured failure so client can present a message
    const status = err?.response?.status;
    const errorData = err?.response?.data;
    return {
      success: false,
      status: 'failed',
      error: (errorData && (errorData.error?.message || errorData.message)) || `Verification failed (${status || 'error'})`,
    };
  }
});