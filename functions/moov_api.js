const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const crypto = require('crypto');

// Shared Firestore
const db = admin.firestore();

// Moov config (must be set via: firebase functions:config:set ...)
const MOOV_BASE_URL = functions.config().moov?.base_url || 'https://api.moov.io';
const MOOV_PUBLIC_KEY = functions.config().moov?.public_key;
const MOOV_PRIVATE_KEY = functions.config().moov?.private_key;
const MOOV_CLIENT_ID = functions.config().moov?.client_id;
const MOOV_CLIENT_SECRET = functions.config().moov?.client_secret;
const MOOV_PLATFORM_ACCOUNT_ID = functions.config().moov?.platform_account_id; // your platform/facilitator account ID

if (!MOOV_PUBLIC_KEY || !MOOV_PRIVATE_KEY || !MOOV_CLIENT_ID || !MOOV_CLIENT_SECRET) {
  console.warn('[moov_api] Missing Moov credentials in functions config. Set moov.public_key, moov.private_key, moov.client_id, moov.client_secret');
}

// Simple in-memory token cache
let cachedToken = null;
let cachedTokenExpiresAt = 0;

async function getMoovAccessToken(scopes) {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && now < cachedTokenExpiresAt - 60) {
    return cachedToken;
  }

  const basic = Buffer.from(`${MOOV_PUBLIC_KEY}:${MOOV_PRIVATE_KEY}`).toString('base64');
  const url = `${MOOV_BASE_URL}/oauth2/token`;

  const body = {
    grant_type: 'client_credentials',
    client_id: MOOV_CLIENT_ID,
    client_secret: MOOV_CLIENT_SECRET,
    scope: Array.isArray(scopes) ? scopes.join(' ') : (scopes || ''),
  };

  const resp = await axios.post(url, body, {
    headers: {
      'Authorization': `Basic ${basic}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    timeout: 10000,
  });

  const { access_token, expires_in } = resp.data;
  cachedToken = access_token;
  cachedTokenExpiresAt = now + (expires_in || 3600);
  return cachedToken;
}

function moovHeaders(token, extra = {}) {
  return {
    'Authorization': `Bearer ${token}`,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    ...extra,
  };
}

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
    // Create account
    const token = await getMoovAccessToken(['/accounts.write']);
    const createResp = await axios.post(`${MOOV_BASE_URL}/accounts`, {
      accountType: 'individual',
      profile: {
        individual: {
          name: { firstName, lastName },
          email,
          phone: phone ? { number: phone, countryCode: '1' } : undefined,
        },
      },
      foreignId: uid,
    }, { headers: moovHeaders(token), timeout: 15000 });

    const account = createResp.data;

    // Request capabilities (transfers, send-funds, wallet)
    try {
      const capToken = await getMoovAccessToken([`/accounts/${account.accountID}/capabilities.write`]);
      await axios.post(`${MOOV_BASE_URL}/accounts/${account.accountID}/capabilities`, {
        capabilities: ['transfers', 'send-funds', 'wallet'],
      }, { headers: moovHeaders(capToken), timeout: 15000 });
    } catch (e) {
      console.warn('[moov_api] capabilities request failed:', e?.response?.data || e.message);
    }

    await saveUserMoovAccountId(uid, account.accountID, account.status);

    return { success: true, accountId: account.accountID, data: account };
  } catch (err) {
    console.error('[moov_api] createMoovAccount failed:', err?.response?.data || err.message);
    throw new functions.https.HttpsError('internal', 'Failed to create Moov account');
  }
});

// Get or create Moov account for the authenticated user
exports.getOrCreateMoovAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  const uid = context.auth.uid;

  // Check Firestore first
  const userDoc = await db.collection('users').doc(uid).get();
  const existing = userDoc.exists ? userDoc.data() : null;
  if (existing?.moovAccountId) {
    return { success: true, accountId: existing.moovAccountId };
  }

  // If not present, require the client to pass email/name to create
  throw new functions.https.HttpsError('failed-precondition', 'No Moov account. Call createMoovAccount with user details.');
});

// Get Moov account by ID (or current user's account)
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
    const token = await getMoovAccessToken([`/accounts/${accId}/profile.read`]);
    const resp = await axios.get(`${MOOV_BASE_URL}/accounts/${accId}`, {
      headers: moovHeaders(token),
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
    const token = await getMoovAccessToken([`/accounts/${accId}/payment-methods.read`]);
    const resp = await axios.get(`${MOOV_BASE_URL}/accounts/${accId}/payment-methods`, {
      headers: moovHeaders(token),
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
    const token = await getMoovAccessToken([`/accounts/${accountId}/cards.write`, `/accounts/${accountId}/bank-accounts.write`]);
    await axios.delete(`${MOOV_BASE_URL}/accounts/${accountId}/payment-methods/${paymentMethodId}`, {
      headers: moovHeaders(token),
      timeout: 10000,
    });
    return { success: true };
  } catch (err) {
    console.error('[moov_api] deletePaymentMethod failed:', err?.response?.data || err.message);
    throw new functions.https.HttpsError('internal', 'Failed to delete payment method');
  }
});

// Create P2P transfer between two Moov accounts
exports.createP2PTransfer = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  if (!MOOV_PLATFORM_ACCOUNT_ID) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Moov platform account id is not configured. Set functions config moov.platform_account_id.'
    );
  }

  const { senderAccountId, recipientAccountId, amount, currency = 'USD', description } = data || {};
  if (!senderAccountId || !recipientAccountId || !amount) {
    throw new functions.https.HttpsError('invalid-argument', 'senderAccountId, recipientAccountId, and amount are required');
  }

  try {
    // Per docs, transfers scopes are restricted to the platform account ID
    // so request a token scoped for transfers from the platform account
    const token = await getMoovAccessToken([`/accounts/${MOOV_PLATFORM_ACCOUNT_ID}/transfers.write`]);

    const idempotencyKey = crypto.randomUUID();

    const resp = await axios.post(`${MOOV_BASE_URL}/transfers`, {
      source: { account: { accountID: senderAccountId } },
      destination: { account: { accountID: recipientAccountId } },
      amount: { currency, value: Math.round(Number(amount) * 100) },
      description: description || 'P2P Transfer',
      metadata: { transferType: 'p2p', userId: context.auth.uid, ts: new Date().toISOString() },
    }, {
      headers: moovHeaders(token, { 'Idempotency-Key': idempotencyKey }),
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
    const token = await getMoovAccessToken(['/bank-accounts.write']);

    const resp = await axios.post(
      `${MOOV_BASE_URL}/bank-accounts/verify`,
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
      { headers: moovHeaders(token), timeout: 15000 }
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