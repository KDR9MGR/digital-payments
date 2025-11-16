# App Store and Play Store Subscription Configuration Guide

This guide covers the complete setup process for configuring the $1.99/month subscription product in both Google Play Store and Apple App Store.

## Overview

The XPay app offers a single subscription product:
- **Monthly Subscription**: $1.99 USD per month
- **Product ID**: `DP07071990`
- **Description**: Premium features and unlimited transactions

## Google Play Store Configuration

### Step 1: Google Play Console Setup

1. **Access Google Play Console**
   - Go to [Google Play Console](https://play.google.com/console)
   - Sign in with your developer account
   - Select your app: `com.digitalpayments`

2. **Navigate to Subscriptions**
   - In the left sidebar, go to **Monetize** > **Subscriptions**
   - Click **Create subscription**

3. **Create Subscription Product**
   ```
   Product ID: DP07071990
   Name: Digital Payments -Premium
   Description: Get unlimited transactions, premium features, and priority support with XPay Premium.
   ```

4. **Configure Pricing**
   ```
   Base Plan ID: monthly-199
   Billing Period: 1 month
   Price: $1.99 USD
   Free Trial: None (optional: 7 days)
   Grace Period: 3 days
   ```

5. **Set Up Offers (Optional)**
   - Introductory offer: First month for $0.99
   - Promotional codes for marketing campaigns

### Step 2: Android App Configuration

1. **Update build.gradle**
   ```gradle
   // In android/app/build.gradle
   dependencies {
       implementation 'com.android.billingclient:billing:6.0.1'
       // ... other dependencies
   }
   ```

2. **Add Permissions**
   ```xml
   <!-- In android/app/src/main/AndroidManifest.xml -->
   <uses-permission android:name="com.android.vending.BILLING" />
   <uses-permission android:name="android.permission.INTERNET" />
   ```

3. **Configure ProGuard (for release builds)**
   ```proguard
   # In android/app/proguard-rules.pro
   -keep class com.android.billingclient.** { *; }
   -keep class com.android.vending.billing.** { *; }
   ```

### Step 3: Testing on Google Play

1. **Upload APK/AAB**
   - Build and upload your app to Internal Testing track
   - Ensure the subscription product is active

2. **Add Test Accounts**
   - Go to **Setup** > **License testing**
   - Add test Gmail accounts
   - Set license response to "RESPOND_NORMALLY"

3. **Test Purchase Flow**
   - Install app from Play Store (Internal Testing)
   - Test subscription purchase with test account
   - Verify receipt validation works

## Apple App Store Configuration

### Step 1: iOS Project Setup

1. **Create iOS Project** (if not exists)
   ```bash
   flutter create --platforms=ios .
   ```

2. **Configure Xcode Project**
   - Open `ios/Runner.xcworkspace` in Xcode
   - Set Bundle Identifier: `com.digitalpayments`
   - Configure signing with your Apple Developer account

3. **Enable In-App Purchase Capability**
   - In Xcode, select Runner target
   - Go to **Signing & Capabilities**
   - Click **+ Capability**
   - Add **In-App Purchase**

### Step 2: App Store Connect Setup

1. **Access App Store Connect**
   - Go to [App Store Connect](https://appstoreconnect.apple.com)
   - Sign in with your Apple Developer account
   - Select your app or create new app

2. **Configure App Information**
   ```
   Bundle ID: com.digitalpayments
   App Name: XPay - Digital Payments
   Primary Language: English
   ```

3. **Create In-App Purchase**
   - Go to **Features** > **In-App Purchases**
   - Click **+** to create new subscription
   - Select **Auto-Renewable Subscription**

4. **Subscription Details**
   ```
   Product ID: DP07071990
   Reference Name: Digital Payments -Premium
   Subscription Group: XPay Premium
   ```

5. **Subscription Information**
   ```
   Display Name: XPay Premium
   Description: Unlock unlimited transactions, premium features, and priority customer support.
   Duration: 1 Month
   Price: $1.99 USD (Tier 2)
   ```

6. **Localization**
   - Add localizations for target markets
   - Translate subscription name and description

### Step 3: iOS App Configuration

1. **Update Info.plist**
   ```xml
   <!-- In ios/Runner/Info.plist -->
   <key>SKAdNetworkItems</key>
   <array>
       <!-- Add SKAdNetwork IDs if using ads -->
   </array>
   ```

2. **Configure Capabilities**
   - Ensure In-App Purchase capability is enabled
   - Add StoreKit configuration file (optional for testing)

### Step 4: Testing on iOS

1. **Create Sandbox Test Account**
   - In App Store Connect, go to **Users and Access** > **Sandbox Testers**
   - Create test Apple ID for testing purchases

2. **Configure Test Environment**
   - On iOS device, sign out of App Store
   - Don't sign in until prompted during testing
   - Use sandbox test account when prompted

3. **Test Purchase Flow**
   - Install app via Xcode or TestFlight
   - Test subscription purchase
   - Verify receipt validation

## Backend Configuration

### Step 1: Server-Side Receipt Validation

1. **Google Play Validation**
   ```javascript
   // Firebase Functions example
   const {google} = require('googleapis');
   
   async function validateGooglePlayReceipt(packageName, productId, purchaseToken) {
     const auth = new google.auth.GoogleAuth({
       scopes: ['https://www.googleapis.com/auth/androidpublisher']
     });
     
     const androidpublisher = google.androidpublisher({
       version: 'v3',
       auth: auth
     });
     
     const result = await androidpublisher.purchases.subscriptions.get({
       packageName: packageName,
       subscriptionId: productId,
       token: purchaseToken
     });
     
     return result.data;
   }
   ```

2. **Apple App Store Validation**
   ```javascript
   // Firebase Functions example
   const axios = require('axios');
   
   async function validateAppleReceipt(receiptData, isProduction = false) {
     const url = isProduction 
       ? 'https://buy.itunes.apple.com/verifyReceipt'
       : 'https://sandbox.itunes.apple.com/verifyReceipt';
     
     const response = await axios.post(url, {
       'receipt-data': receiptData,
       'password': process.env.APPLE_SHARED_SECRET
     });
     
     return response.data;
   }
   ```

### Step 2: Webhook Configuration

1. **Google Play Real-time Developer Notifications**
   ```javascript
   // Set up Pub/Sub topic and subscription
   // Configure webhook endpoint in Google Play Console
   
   exports.handlePlayStoreNotification = functions.pubsub
     .topic('play-store-notifications')
     .onPublish(async (message) => {
       const notification = JSON.parse(Buffer.from(message.data, 'base64').toString());
       // Handle subscription state changes
     });
   ```

2. **Apple App Store Server Notifications**
   ```javascript
   // Configure webhook endpoint in App Store Connect
   
   exports.handleAppStoreNotification = functions.https.onRequest(async (req, res) => {
     const notification = req.body;
     // Verify signature and handle subscription events
   });
   ```

## Environment Variables

### Required Environment Variables

```bash
# Google Play
GOOGLE_PLAY_SERVICE_ACCOUNT_KEY=path/to/service-account.json
GOOGLE_PLAY_PACKAGE_NAME=com.digitalpayments

# Apple App Store
APPLE_SHARED_SECRET=your_shared_secret_here
APPLE_BUNDLE_ID=com.digitalpayments

# App Configuration
SUBSCRIPTION_PRODUCT_ID=DP07071990
SUBSCRIPTION_PRICE_USD=1.99
```

### Firebase Functions Configuration

```bash
# Set environment variables
firebase functions:config:set \
  googleplay.service_account_key="$(cat path/to/service-account.json)" \
  googleplay.package_name="com.digitalpayments" \
  apple.shared_secret="your_shared_secret" \
  apple.bundle_id="com.digitalpayments"
```

## Testing Checklist

### Pre-Launch Testing

- [ ] **Google Play Store**
  - [ ] Subscription product is active in Play Console
  - [ ] Test purchase with sandbox account
  - [ ] Receipt validation works correctly
  - [ ] Subscription renewal tested
  - [ ] Cancellation flow tested

- [ ] **Apple App Store**
  - [ ] Subscription approved in App Store Connect
  - [ ] Test purchase with sandbox account
  - [ ] Receipt validation works correctly
  - [ ] Subscription renewal tested
  - [ ] Cancellation flow tested

- [ ] **Backend Integration**
  - [ ] Server-side receipt validation
  - [ ] Webhook notifications working
  - [ ] Database updates on subscription events
  - [ ] Error handling and logging

### Production Deployment

1. **Google Play Store**
   - Upload production APK/AAB
   - Activate subscription products
   - Submit for review

2. **Apple App Store**
   - Upload production build via Xcode/Transporter
   - Submit subscription for review
   - Submit app for review

3. **Backend**
   - Deploy Firebase Functions to production
   - Configure production environment variables
   - Set up monitoring and alerts

## Troubleshooting

### Common Issues

1. **"Product not found" Error**
   - Verify product ID matches exactly
   - Ensure product is active in store console
   - Check app bundle ID matches store configuration

2. **Receipt Validation Fails**
   - Verify shared secret (Apple) or service account (Google)
   - Check environment (sandbox vs production)
   - Ensure proper error handling for network issues

3. **Subscription Not Renewing**
   - Check webhook configuration
   - Verify server-side subscription status updates
   - Review subscription grace period settings

### Support Resources

- [Google Play Billing Documentation](https://developer.android.com/google/play/billing)
- [Apple In-App Purchase Documentation](https://developer.apple.com/in-app-purchase/)
- [Flutter In-App Purchase Plugin](https://pub.dev/packages/in_app_purchase)

## Security Considerations

1. **Never store sensitive keys in app code**
2. **Always validate receipts server-side**
3. **Implement proper error handling**
4. **Use HTTPS for all API communications**
5. **Regularly rotate API keys and secrets**
6. **Monitor for fraudulent transactions**

---

**Note**: This configuration supports the single $1.99/month subscription product as specified. Additional products can be added following the same process with different product IDs and pricing tiers.