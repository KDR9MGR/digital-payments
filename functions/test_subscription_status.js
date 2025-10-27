const admin = require('firebase-admin');
const functions = require('firebase-functions');

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = require('./firebase-service-account.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'digital-payments-52cac'
  });
}

const db = admin.firestore();

async function checkSubscriptionStatus() {
  try {
    console.log('🔍 Checking subscription status...');
    
    // Get all subscriptions
    const subscriptionsSnapshot = await db.collection('subscriptions').get();
    console.log(`📊 Total subscriptions found: ${subscriptionsSnapshot.size}`);
    
    if (subscriptionsSnapshot.empty) {
      console.log('❌ No subscriptions found in database');
      return;
    }
    
    // Show recent subscriptions
    subscriptionsSnapshot.forEach(doc => {
      const data = doc.data();
      console.log('\n📋 Subscription:', {
        id: doc.id,
        userId: data.userId,
        status: data.status,
        planType: data.planType,
        expiryDate: data.expiryDate?.toDate?.() || data.expiryDate,
        createdAt: data.createdAt?.toDate?.() || data.createdAt,
        paymentMethod: data.paymentMethod
      });
    });
    
    // Check users collection for subscription status
    console.log('\n🔍 Checking users collection...');
    const usersSnapshot = await db.collection('users').where('isSubscribed', '==', true).get();
    console.log(`👥 Users with isSubscribed=true: ${usersSnapshot.size}`);
    
    usersSnapshot.forEach(doc => {
      const data = doc.data();
      console.log('\n👤 Subscribed User:', {
        id: doc.id,
        email: data.email,
        isSubscribed: data.isSubscribed,
        subscriptionExpiry: data.subscriptionExpiry?.toDate?.() || data.subscriptionExpiry
      });
    });
    
  } catch (error) {
    console.error('❌ Error checking subscription status:', error);
  }
}

// Run the check
checkSubscriptionStatus().then(() => {
  console.log('\n✅ Subscription status check completed');
  process.exit(0);
}).catch(error => {
  console.error('❌ Failed to check subscription status:', error);
  process.exit(1);
});