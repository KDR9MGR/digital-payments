# Sandbox Testing Guide for Subscription Validation

This guide will help you test your subscription validation system in a sandbox environment before going live.

## Prerequisites

1. ✅ Firebase Functions deployed with subscription validation
2. ✅ Google Play API configured with service account
3. ✅ Firestore security rules implemented
4. ✅ Flutter app with in-app purchase integration

## Step 1: Set Up Google Play Console for Testing

### 1.1 Add License Testers

1. Go to [Google Play Console](https://play.google.com/console/)
2. Navigate to **Setup** > **License testing**
3. Add your email addresses to the **License testers** list
4. Set **License test response** to "RESPOND_NORMALLY"
5. Click **Save changes**

### 1.2 Create Test Products

1. Go to **Monetize** > **Products** > **In-app products**
2. Create test subscription products:
   - **Product ID**: `test_monthly_premium`
   - **Name**: `Test Monthly Premium`
   - **Description**: `Test monthly subscription`
   - **Price**: Set a low price (e.g., $0.99)
   - **Subscription period**: 1 month
3. Activate the products

### 1.3 Upload to Internal Testing

1. Go to **Testing** > **Internal testing**
2. Create a new release
3. Upload your signed APK/AAB
4. Add testers (same emails as license testers)
5. Publish the release

## Step 2: Configure Firebase for Testing

### 2.1 Set Up Test Environment Variables

```bash
# Set test-specific configurations
firebase functions:config:set testing.enabled=true
firebase functions:config:set testing.log_level="debug"
firebase functions:config:set googleplay.sandbox_mode=true
```

### 2.2 Deploy Functions with Test Configuration

```bash
firebase deploy --only functions
```

## Step 3: Test Subscription Flow

### 3.1 Install Test App

1. **Important**: Install the app from Google Play Store (Internal Testing track)
2. **Do NOT** sideload the APK - this won't work with Google Play Billing
3. Sign in with a test account (license tester email)

### 3.2 Test Purchase Flow

1. **Initiate Purchase**:
   - Open your app
   - Navigate to subscription screen
   - Select a test subscription product
   - Complete the purchase flow

2. **Verify Purchase Token**:
   - Check your app logs for the purchase token
   - Ensure the token is being sent to Firebase Function

3. **Check Firebase Function Logs**:
   ```bash
   firebase functions:log --only validateGooglePlayPurchaseReal
   ```
   Look for:
   - ✅ Purchase token received
   - ✅ Google Play API call successful
   - ✅ Subscription status validated
   - ✅ Firestore updated

### 3.3 Verify Firestore Updates

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Navigate to **Firestore Database**
3. Check the user's document:
   ```javascript
   /users/{userId}/subscription
   {
     "status": "active",
     "productId": "test_monthly_premium",
     "expiryDate": "2024-02-15T10:30:00.000Z",
     "platform": "android",
     "purchaseToken": "...",
     "transactionId": "...",
     "lastUpdated": "2024-01-15T10:30:00.000Z"
   }
   ```

## Step 4: Test Edge Cases

### 4.1 Test Invalid Purchase Token

```javascript
// Test with invalid token
const testInvalidToken = async () => {
  try {
    const result = await firebase.functions().httpsCallable('validateGooglePlayPurchaseReal')({
      purchaseToken: 'invalid_token_123',
      productId: 'test_monthly_premium',
      packageName: 'com.yourapp.package'
    });
    console.log('Result:', result.data);
  } catch (error) {
    console.log('Expected error:', error.message);
  }
};
```

### 4.2 Test Duplicate Purchase Token

1. Use the same purchase token twice
2. Verify the second call is rejected
3. Check logs for duplicate detection

### 4.3 Test Expired Subscription

1. Wait for test subscription to expire (or manually set past expiry)
2. Call validation function
3. Verify status is set to "inactive"

## Step 5: Test Subscription Status Check

```javascript
// Test subscription status check
const checkStatus = async () => {
  const result = await firebase.functions().httpsCallable('checkSubscriptionStatus')();
  console.log('Subscription status:', result.data);
};
```

Expected response:
```javascript
{
  "hasActiveSubscription": true,
  "subscription": {
    "status": "active",
    "productId": "test_monthly_premium",
    "expiryDate": "2024-02-15T10:30:00.000Z",
    "platform": "android"
  }
}
```

## Step 6: Test Security Rules

### 6.1 Test Direct Firestore Write (Should Fail)

```javascript
// This should be rejected by security rules
const testDirectWrite = async () => {
  try {
    await firebase.firestore()
      .doc(`users/${currentUserId}`)
      .set({
        subscription: {
          status: 'active' // This should fail
        }
      }, { merge: true });
    console.log('❌ Security rules failed - direct write succeeded');
  } catch (error) {
    console.log('✅ Security rules working - direct write blocked:', error.message);
  }
};
```

### 6.2 Test Read Access (Should Succeed)

```javascript
// This should succeed
const testRead = async () => {
  try {
    const doc = await firebase.firestore()
      .doc(`users/${currentUserId}`)
      .get();
    console.log('✅ Read access working:', doc.data());
  } catch (error) {
    console.log('❌ Read access failed:', error.message);
  }
};
```

## Step 7: Test Webhook Integration (Optional)

### 7.1 Simulate Google Play Webhook

```bash
# Test webhook endpoint
curl -X POST https://your-region-your-project.cloudfunctions.net/googlePlayWebhook \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "data": "base64-encoded-notification-data",
      "messageId": "test-message-id"
    }
  }'
```

## Step 8: Performance Testing

### 8.1 Test Concurrent Validations

```javascript
// Test multiple simultaneous validations
const testConcurrency = async () => {
  const promises = [];
  for (let i = 0; i < 10; i++) {
    promises.push(
      firebase.functions().httpsCallable('checkSubscriptionStatus')()
    );
  }
  
  const results = await Promise.all(promises);
  console.log('All requests completed:', results.length);
};
```

### 8.2 Monitor Function Performance

1. Go to Firebase Console > Functions
2. Check execution times and error rates
3. Monitor memory usage and timeouts

## Step 9: Test Cleanup

### 9.1 Cancel Test Subscriptions

1. Go to Google Play Store
2. Navigate to **Account** > **Payments & subscriptions**
3. Cancel test subscriptions
4. Verify your app handles cancellation correctly

### 9.2 Clear Test Data

```javascript
// Clean up test data from Firestore
const cleanup = async () => {
  await firebase.firestore()
    .doc(`users/${testUserId}`)
    .delete();
  console.log('Test data cleaned up');
};
```

## Common Issues and Solutions

### Issue 1: "Purchase token not found"
**Solution**: Ensure you're using a real purchase token from Google Play Billing, not a test/mock token.

### Issue 2: "Insufficient permissions"
**Solution**: Verify service account has "View financial data" permission in Google Play Console.

### Issue 3: "Package name mismatch"
**Solution**: Ensure package name in Firebase config matches your app's package name exactly.

### Issue 4: "Subscription not found in Firestore"
**Solution**: Check Firebase Function logs for errors during Firestore write operations.

### Issue 5: "Security rules blocking read access"
**Solution**: Verify user is authenticated and accessing their own data.

## Success Criteria

✅ **Purchase Flow**:
- User can purchase subscription in test app
- Purchase token is captured and sent to Firebase
- Firebase Function validates token with Google Play API
- Firestore is updated with subscription status

✅ **Security**:
- Users cannot directly modify subscription status
- Users can read their own subscription data
- Invalid tokens are rejected

✅ **Error Handling**:
- Invalid purchase tokens return appropriate errors
- Duplicate tokens are detected and handled
- Network failures are handled gracefully

✅ **Performance**:
- Validation completes within 5 seconds
- Concurrent requests are handled properly
- No memory leaks or timeouts

## Next Steps

After successful sandbox testing:
1. Switch to production Google Play API endpoints
2. Update Firebase config for production
3. Deploy to production Firebase project
4. Monitor real user subscriptions
5. Set up alerts for validation failures

## Support

If you encounter issues during testing:
1. Check Firebase Function logs
2. Verify Google Play Console configuration
3. Test with different devices and accounts
4. Review Firestore security rules
5. Monitor API quotas and limits