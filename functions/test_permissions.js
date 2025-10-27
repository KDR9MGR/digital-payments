const admin = require('firebase-admin');
const { google } = require('googleapis');

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = require('./firebase-service-account.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'digital-payments-52cac'
  });
}

async function testGooglePlayPermissions() {
  try {
    console.log('🔍 Testing Google Play API permissions...');
    
    // Initialize Google Play Developer API
    const auth = new google.auth.GoogleAuth({
      keyFile: './firebase-service-account.json',
      scopes: ['https://www.googleapis.com/auth/androidpublisher']
    });
    
    const androidpublisher = google.androidpublisher({
      version: 'v3',
      auth: auth
    });
    
    console.log('✅ Google Play API client initialized successfully');
    
    // Test subscription access with a real purchase token from the logs
    const testPurchaseToken = 'emempamdhdknollipbmdmean.AO-J1Ozftnu7xShM8-oHHKF8fr1X-Oz7ttOXFEaUWCz5BzDjm4KNTmkbqTKDlaBlEAZY0EFctJ2avflCmHWJ_oFlBFLfN1BPxQ';
    const packageName = 'com.digitalpayments';
    const subscriptionId = '07071990';
    
    try {
      console.log('🔍 Testing subscription validation...');
      const result = await androidpublisher.purchases.subscriptions.get({
        packageName: packageName,
        subscriptionId: subscriptionId,
        token: testPurchaseToken
      });
      
      console.log('✅ SUCCESS! Subscription validation worked!');
      console.log('📋 Subscription details:', {
        orderId: result.data.orderId,
        purchaseState: result.data.purchaseState,
        autoRenewing: result.data.autoRenewing,
        expiryTimeMillis: result.data.expiryTimeMillis
      });
      
    } catch (error) {
      console.log('❌ Subscription validation failed:', error.message);
      if (error.code === 401) {
        console.log('🔍 Still getting 401 error - permissions need more time to propagate');
        console.log('⏰ Please wait 10-15 minutes after setting permissions and try again');
        console.log('📝 Make sure these permissions are granted in Google Play Console:');
        console.log('   - Financial data, orders, and cancellation survey responses');
        console.log('   - App information and performance');
      }
    }
    
  } catch (error) {
    console.error('❌ Error testing Google Play permissions:', error.message);
  }
}

// Run the test
testGooglePlayPermissions().then(() => {
  console.log('\n✅ Permission test completed');
  process.exit(0);
}).catch(error => {
  console.error('❌ Failed to test permissions:', error);
  process.exit(1);
});