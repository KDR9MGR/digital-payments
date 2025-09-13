# Firebase Subscription Backend Deployment Guide

This guide will help you deploy the comprehensive Firebase subscription backend system with Google Play, Apple App Store, and Moov payment integrations.

## Prerequisites

1. **Firebase Project Setup**
   - Create a Firebase project at https://console.firebase.google.com
   - Enable Firestore Database
   - Enable Firebase Functions
   - Enable Firebase Authentication
   - Upgrade to Blaze plan (required for external API calls)

2. **Google Play Console Setup**
   - Create a service account in Google Cloud Console
   - Download the service account JSON key
   - Enable Google Play Developer API
   - Grant necessary permissions to the service account

3. **Apple App Store Connect Setup**
   - Generate App Store Connect API key
   - Note down the shared secret for in-app purchases

4. **Moov Account Setup**
   - Create a Moov developer account
   - Obtain API keys and access tokens

## Installation Steps

### 1. Install Dependencies

```bash
cd functions
npm install
```

### 2. Configure Environment Variables

Set up Firebase configuration using the Firebase CLI:

```bash
# Google Play Configuration
firebase functions:config:set googleplay.package_name="com.yourapp.package"
firebase functions:config:set googleplay.project_id="your-google-cloud-project-id"
firebase functions:config:set googleplay.private_key_id="your-private-key-id"
firebase functions:config:set googleplay.private_key="-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY_CONTENT\n-----END PRIVATE KEY-----"
firebase functions:config:set googleplay.client_email="your-service-account@your-project.iam.gserviceaccount.com"
firebase functions:config:set googleplay.client_id="your-client-id"
firebase functions:config:set googleplay.client_x509_cert_url="https://www.googleapis.com/robot/v1/metadata/x509/your-service-account%40your-project.iam.gserviceaccount.com"
firebase functions:config:set googleplay.webhook_secret="your-google-play-webhook-secret"

# Apple App Store Configuration
firebase functions:config:set apple.shared_secret="your-apple-shared-secret"
firebase functions:config:set apple.bundle_id="com.yourapp.bundle"
firebase functions:config:set apple.webhook_secret="your-apple-webhook-secret"

# Moov Configuration
firebase functions:config:set moov.api_key="your-moov-api-key"
firebase functions:config:set moov.access_token="your-moov-access-token"
firebase functions:config:set moov.base_url="https://api.moov.io"
```

### 3. Deploy Functions

```bash
firebase deploy --only functions
```

## Firestore Security Rules

Update your Firestore security rules to secure subscription data:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Subscriptions can only be read by the owner
    match /subscriptions/{subscriptionId} {
      allow read: if request.auth != null && request.auth.uid == resource.data.userId;
      allow write: if false; // Only backend functions can write
    }
    
    // Analytics and events are read-only for authenticated users
    match /daily_analytics/{document} {
      allow read: if request.auth != null;
      allow write: if false;
    }
    
    match /subscription_events/{document} {
      allow read: if request.auth != null && request.auth.uid == resource.data.userId;
      allow write: if false;
    }
    
    // Transactions can only be read by the owner
    match /transactions/{transactionId} {
      allow read: if request.auth != null && request.auth.uid == resource.data.userId;
      allow write: if false;
    }
  }
}
```

## Webhook Configuration

### Google Play Console Webhooks

1. Go to Google Play Console > Developer account > API access
2. Create or select your service account
3. Set up Real-time developer notifications:
   - Topic name: `projects/your-project-id/topics/google-play-notifications`
   - Endpoint URL: `https://your-region-your-project-id.cloudfunctions.net/googlePlayWebhook`

### Apple App Store Server Notifications

1. Go to App Store Connect > My Apps > [Your App] > App Information
2. Set up Server-to-Server Notifications:
   - Production Server URL: `https://your-region-your-project-id.cloudfunctions.net/appleAppStoreWebhook`
   - Sandbox Server URL: `https://your-region-your-project-id.cloudfunctions.net/appleAppStoreWebhook`

### Moov Webhooks

1. Configure Moov webhooks in your Moov dashboard
2. Set endpoint URL: `https://your-region-your-project-id.cloudfunctions.net/moovWebhook`
3. Subscribe to events: `account.created`, `transfer.completed`, `transfer.failed`, `payment_method.created`

## Testing

### 1. Test Subscription Validation

```javascript
// Test Google Play validation
const result = await firebase.functions().httpsCallable('validateGooglePlayPurchaseReal')({
  purchaseToken: 'test-purchase-token',
  productId: 'your-product-id',
  packageName: 'com.yourapp.package'
});

// Test Apple Pay validation
const result = await firebase.functions().httpsCallable('validateApplePayPurchaseReal')({
  receiptData: 'base64-encoded-receipt',
  productId: 'your-product-id'
});
```

### 2. Test Subscription Status Check

```javascript
const status = await firebase.functions().httpsCallable('checkSubscriptionStatus')();
console.log('Subscription status:', status.data);
```

### 3. Test Subscription Cancellation

```javascript
const result = await firebase.functions().httpsCallable('cancelSubscription')();
console.log('Cancellation result:', result.data);
```

## Monitoring and Analytics

### 1. View Analytics Data

Query daily analytics from Firestore:

```javascript
const analytics = await db.collection('daily_analytics')
  .orderBy('date', 'desc')
  .limit(30)
  .get();

analytics.forEach(doc => {
  const data = doc.data();
  console.log(`${data.date.toDate().toISOString().split('T')[0]}: ${data.activeSubscriptions} active, ${data.newSubscriptions} new, $${data.totalRevenue} revenue`);
});
```

### 2. Monitor Subscription Events

```javascript
const events = await db.collection('subscription_events')
  .where('userId', '==', currentUserId)
  .orderBy('timestamp', 'desc')
  .limit(50)
  .get();

events.forEach(doc => {
  const event = doc.data();
  console.log(`${event.eventType} at ${event.timestamp.toDate()}`);
});
```

## Scheduled Functions

The following scheduled functions will run automatically:

- **checkExpiredSubscriptions**: Runs every hour to check for expired subscriptions and manage grace periods
- **processSubscriptionRenewals**: Runs daily at 2 AM UTC to process subscription renewals
- **generateDailyAnalytics**: Runs daily at 1 AM UTC to generate analytics reports

## Security Best Practices

1. **Environment Variables**: Never commit API keys or secrets to version control
2. **Webhook Validation**: Always validate webhook signatures (implemented in the webhook handlers)
3. **Receipt Validation**: Always validate receipts server-side before granting access
4. **Rate Limiting**: Consider implementing rate limiting for API endpoints
5. **Logging**: Monitor function logs for suspicious activity

## Troubleshooting

### Common Issues

1. **Google Play API Errors**
   - Ensure service account has proper permissions
   - Check that the package name matches your app
   - Verify the purchase token is valid

2. **Apple Receipt Validation Errors**
   - Use sandbox URL for testing: `https://sandbox.itunes.apple.com/verifyReceipt`
   - Use production URL for live app: `https://buy.itunes.apple.com/verifyReceipt`
   - Ensure shared secret is correct

3. **Webhook Issues**
   - Check function logs for webhook processing errors
   - Verify webhook URLs are accessible
   - Ensure proper signature validation

### Debugging

1. **View Function Logs**
   ```bash
   firebase functions:log
   ```

2. **Test Functions Locally**
   ```bash
   firebase emulators:start --only functions,firestore
   ```

3. **Monitor Performance**
   - Use Firebase Console to monitor function execution times
   - Set up alerts for function failures

## Support

For additional support:
- Firebase Documentation: https://firebase.google.com/docs/functions
- Google Play Billing: https://developer.android.com/google/play/billing
- Apple In-App Purchase: https://developer.apple.com/in-app-purchase/
- Moov API Documentation: https://docs.moov.io/