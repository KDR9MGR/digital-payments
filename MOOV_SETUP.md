# Moov.io Payment Integration Setup Guide

This guide walks you through setting up Moov.io payment processing with Google Pay and Apple Pay for subscriptions in your XPay Flutter app.

## Prerequisites

1. **Moov.io Account**: Login credentials provided
   - Email: Mossmalcolm8@gmail.com
   - Password: Kingme1990$12
   - API Key: stGOlQhih6BdxYhV

2. **Google Console Access**:
   - Email: malcommosse@gmail.com
   - Password: Dpworld1990

3. **Apple Developer Account**:
   - Email: malcmoss47@gmail.com
   - Password: Dpworld1990

4. **Firebase Project** with Blaze plan (for Cloud Functions)
5. **Flutter development environment**

## Step 1: Moov.io Dashboard Setup

### 1.1 Complete Account Setup
1. Go to [Moov.io Dashboard](https://dashboard.moov.io)
2. Login with provided credentials
3. Complete business verification if required
4. Set up your merchant account for receiving payments

### 1.2 Configure Webhooks
1. In Moov Dashboard → Settings → Webhooks
2. Add endpoint: `https://your-region-your-project.cloudfunctions.net/moovWebhook`
3. Select events:
   - `account.created`
   - `transfer.completed`
   - `transfer.failed`
   - `payment_method.created`
4. Save webhook configuration

### 1.3 Get Your Merchant Account ID
1. In Moov Dashboard → Accounts
2. Copy your business account ID
3. Update `lib/services/moov_service.dart` line 160:
   ```dart
   'accountID': 'YOUR_ACTUAL_MERCHANT_ACCOUNT_ID',
   ```

## Step 2: Google Pay Setup

### 2.1 Google Pay Console Configuration
1. Go to [Google Pay & Wallet Console](https://pay.google.com/business/console/)
2. Login with Google Console credentials
3. Create a new integration for your app
4. Configure payment methods and merchant settings

### 2.2 Update Android Configuration
1. Get your Google Pay Merchant ID from the console
2. Update `lib/config/moov_config.dart`:
   ```dart
   'merchantId': 'YOUR_ACTUAL_GOOGLE_PAY_MERCHANT_ID',
   'gatewayMerchantId': 'YOUR_MOOV_MERCHANT_ID'
   ```

### 2.3 Android Manifest Permissions
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

## Step 3: Apple Pay Setup

### 3.1 Apple Developer Console
1. Go to [Apple Developer Console](https://developer.apple.com)
2. Login with Apple Developer credentials
3. Navigate to Certificates, Identifiers & Profiles
4. Create a Merchant ID for your app

### 3.2 Configure Merchant Identifier
1. Create merchant identifier: `merchant.com.getdigitalpayments.xpay`
2. Update `lib/config/moov_config.dart`:
   ```dart
   'merchantIdentifier': 'merchant.com.getdigitalpayments.xpay',
   ```

### 3.3 iOS Configuration
Add to `ios/Runner/Info.plist`:
```xml
<key>com.apple.developer.in-app-payments</key>
<array>
    <string>merchant.com.getdigitalpayments.xpay</string>
</array>
```

## Step 4: Firebase Functions Setup

### 4.1 Install Dependencies
```bash
cd functions
npm install
```

### 4.2 Configure Environment Variables
```bash
# Set Moov API key
firebase functions:config:set moov.api_key="stGOlQhih6BdxYhV"

# Set Stripe keys (if keeping as fallback)
firebase functions:config:set stripe.secret_key="sk_test_your_stripe_secret"
firebase functions:config:set stripe.webhook_secret="whsec_your_stripe_webhook_secret"
```

### 4.3 Deploy Functions
```bash
firebase deploy --only functions
```

## Step 5: Subscription Plan Configuration

The app is configured with the "Super Payments" subscription:
- **Price**: $1.99 USD
- **Billing Period**: Monthly
- **Features**: Coupons, Brand Deals, Discounts

This configuration is already set in `lib/config/moov_config.dart`.

## Step 6: Testing

### 6.1 Test Google Pay
1. Use a Google account with a test payment method
2. Test on an Android device with Google Pay enabled
3. Verify payments appear in Moov Dashboard

### 6.2 Test Apple Pay
1. Use an iOS device with Apple Pay enabled
2. Add a test card to Apple Wallet
3. Test subscription payment flow

### 6.3 Test Webhooks
1. Use ngrok for local testing:
   ```bash
   ngrok http 5001
   ```
2. Update webhook URL temporarily for testing
3. Monitor Firebase Functions logs

## Step 7: Production Deployment

### 7.1 Update Environment Settings
1. Change Moov environment to production in `lib/config/moov_config.dart`:
   ```dart
   static const bool isProduction = true;
   ```

2. Update Google Pay environment in `android/app/src/main/kotlin/.../MainActivity.kt`:
   ```kotlin
   .setEnvironment(WalletConstants.ENVIRONMENT_PRODUCTION)
   ```

### 7.2 Production Credentials
1. Replace test API keys with production keys
2. Update webhook URLs to production Firebase Functions
3. Test with small amounts before full launch

## Step 8: Security Considerations

### 8.1 API Key Protection
- Never expose API keys in client code
- Use Firebase Functions for all Moov API calls
- Implement proper authentication checks

### 8.2 Webhook Security
- Verify webhook signatures (implement in Firebase Functions)
- Use HTTPS for all webhook endpoints
- Monitor webhook delivery and failures

### 8.3 User Data Protection
- Store minimal payment information
- Encrypt sensitive data in Firestore
- Follow PCI compliance guidelines

## Troubleshooting

### Common Issues

1. **Google Pay not available**:
   - Check device compatibility
   - Verify Google Play Services
   - Ensure test environment is properly configured

2. **Apple Pay not available**:
   - Verify device supports Apple Pay
   - Check merchant identifier configuration
   - Ensure Apple Pay is enabled in device settings

3. **Moov API errors**:
   - Verify API key is correct
   - Check account verification status
   - Monitor rate limits

4. **Firebase Functions errors**:
   - Check function logs: `firebase functions:log`
   - Verify environment variables
   - Test functions locally with emulator

### Debug Commands

```bash
# Run Flutter with debugging
flutter run --debug

# Check Firebase Functions logs
firebase functions:log

# Test locally with emulator
firebase emulators:start

# Deploy specific functions
firebase deploy --only functions:moovWebhook
```

## Support

For technical issues:
1. Check Moov.io documentation: https://docs.moov.io
2. Firebase Functions documentation: https://firebase.google.com/docs/functions
3. Contact Moov support through their dashboard
4. Monitor app analytics for payment conversion rates

## Next Steps

1. Implement subscription management features
2. Add promotional codes and discounts
3. Set up analytics and monitoring
4. Implement customer support chat integration
5. Add more payment methods as needed

---

**Note**: This integration replaces Stripe as the primary payment processor while maintaining Stripe as a fallback option. The app will automatically use Moov + Google Pay/Apple Pay for new subscriptions. 