const admin = require('firebase-admin');
const { validateGooglePlayPurchase } = require('./index');

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = require('./firebase-service-account.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'digital-payments-52cac'
  });
}

async function testPurchaseValidation() {
  try {
    console.log('🔍 Testing Google Play purchase validation...');
    
    // Test with sample data (you'll need to replace with actual purchase token)
    const testData = {
      purchaseToken: 'test_purchase_token_from_your_recent_purchase',
      productId: 'premium_monthly', // or whatever your product ID is
      packageName: 'com.yourapp.package'
    };
    
    console.log('📋 Test data:', testData);
    
    // Create a mock context for the function
    const mockContext = {
      auth: {
        uid: 'test_user_id'
      }
    };
    
    console.log('🚀 Calling validateGooglePlayPurchase function...');
    
    // Call the function
    const result = await validateGooglePlayPurchase(testData, mockContext);
    
    console.log('✅ Function result:', result);
    
  } catch (error) {
    console.error('❌ Error testing purchase validation:', error);
    
    // Check if it's a specific Google Play API error
    if (error.message && error.message.includes('401')) {
      console.log('\n🔍 This is the 401 Unauthorized error we saw in the logs.');
      console.log('📝 The service account dp-playstore-api@digital-payments-52cac.iam.gserviceaccount.com');
      console.log('   needs proper permissions in Google Play Console.');
      console.log('\n🛠️  To fix this:');
      console.log('   1. Go to Google Play Console');
      console.log('   2. Navigate to Setup > API access');
      console.log('   3. Find the service account: dp-playstore-api@digital-payments-52cac.iam.gserviceaccount.com');
      console.log('   4. Grant it "Financial data, orders, and cancellation survey responses" permission');
      console.log('   5. Also grant "App information and performance" permission');
    }
  }
}

// Run the test
testPurchaseValidation().then(() => {
  console.log('\n✅ Purchase validation test completed');
  process.exit(0);
}).catch(error => {
  console.error('❌ Failed to test purchase validation:', error);
  process.exit(1);
});