# Moov Payment Environment Setup Guide

This guide helps you set up the required environment variables and configurations for Moov payments integration.

## Required Environment Variables

### 1. Moov API Configuration

```bash
# Moov API Key (Get from Moov Dashboard)
export MOOV_API_KEY="your_moov_api_key_here"

# Moov Merchant ID (Get from Moov Dashboard)
export MOOV_MERCHANT_ID="your_moov_merchant_id_here"
```

### 2. Google Pay Configuration

```bash
# Google Pay Merchant ID (Get from Google Pay Console)
export GOOGLE_PAY_MERCHANT_ID="your_google_pay_merchant_id_here"
```

### 3. Apple Pay Configuration

```bash
# Apple Pay Merchant ID (Get from Apple Developer Console)
export APPLE_PAY_MERCHANT_ID="merchant.com.getdigitalpayments.xpay"
```

## Setup Steps

### Step 1: Moov Dashboard Setup

1. **Create Moov Account**
   - Go to [Moov Dashboard](https://dashboard.moov.io)
   - Sign up or log in to your account
   - Complete account verification

2. **Get API Credentials**
   - Navigate to "API Keys" section
   - Create a new API key for your application
   - Copy the API key and set it as `MOOV_API_KEY`

3. **Get Merchant ID**
   - Go to "Account Settings"
   - Find your Merchant ID
   - Set it as `MOOV_MERCHANT_ID`

### Step 2: Google Pay Setup

1. **Google Pay Console**
   - Go to [Google Pay Console](https://pay.google.com/business/console)
   - Create or select your business profile
   - Get your Merchant ID
   - Set it as `GOOGLE_PAY_MERCHANT_ID`

2. **Android Configuration**
   - Add Google Pay permissions to `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="com.google.android.gms.permission.ACTIVITY_RECOGNITION" />
   ```

### Step 3: Apple Pay Setup

1. **Apple Developer Console**
   - Go to [Apple Developer Console](https://developer.apple.com)
   - Navigate to "Certificates, Identifiers & Profiles"
   - Create or configure your Merchant ID
   - Set it as `APPLE_PAY_MERCHANT_ID`

2. **iOS Configuration**
   - Add Apple Pay capability to your iOS app
   - Configure merchant identifier in Xcode

### Step 4: Firebase Functions Configuration

1. **Set Firebase Config**
   ```bash
   firebase functions:config:set moov.api_key="your_moov_api_key_here"
   firebase functions:config:set moov.merchant_id="your_moov_merchant_id_here"
   firebase functions:config:set googlepay.merchant_id="your_google_pay_merchant_id_here"
   firebase functions:config:set applepay.merchant_id="merchant.com.getdigitalpayments.xpay"
   ```

2. **Deploy Functions**
   ```bash
   cd functions
   npm install
   cd ..
   firebase deploy --only functions
   ```

### Step 5: Local Development Setup

1. **Create .env file** (for local testing)
   ```bash
   # Create .env file in project root
   touch .env
   ```

2. **Add environment variables to .env**
   ```env
   MOOV_API_KEY=your_moov_api_key_here
   MOOV_MERCHANT_ID=your_moov_merchant_id_here
   GOOGLE_PAY_MERCHANT_ID=your_google_pay_merchant_id_here
   APPLE_PAY_MERCHANT_ID=merchant.com.getdigitalpayments.xpay
   ```

3. **Load environment variables**
   ```bash
   # Add to your shell profile (.bashrc, .zshrc, etc.)
   source .env
   ```

## Validation Commands

### Run Moov Payment Validation
```bash
# Run the validation script
dart validate_moov_payments.dart
```

### Test Firebase Functions Locally
```bash
# Start Firebase emulator
firebase emulators:start --only functions

# Test webhook endpoint
curl -X POST http://localhost:5001/your-project/us-central1/moovWebhook \
  -H "Content-Type: application/json" \
  -d '{"type": "account.created", "data": {"accountID": "test123"}}'
```

### Test API Connection
```bash
# Test Moov API directly
curl -X GET https://api.moov.io/ping \
  -H "Authorization: Bearer $MOOV_API_KEY" \
  -H "Content-Type: application/json"
```

## Troubleshooting

### Common Issues

1. **401 Unauthorized Error**
   - Check if `MOOV_API_KEY` is correctly set
   - Verify API key is active in Moov Dashboard
   - Ensure API key has required permissions

2. **Environment Variables Not Found**
   - Restart your terminal/IDE after setting variables
   - Check if variables are exported correctly
   - Verify .env file is in the correct location

3. **Firebase Functions Not Working**
   - Ensure Firebase CLI is installed and logged in
   - Check if functions are deployed successfully
   - Verify Firebase config variables are set

4. **Google Pay Not Working**
   - Check Google Pay merchant account status
   - Verify Android app signing certificate
   - Ensure Google Play Services is available

5. **Apple Pay Not Working**
   - Check Apple Pay merchant certificate
   - Verify iOS app capabilities
   - Ensure device supports Apple Pay

## Testing Checklist

- [ ] Environment variables are set
- [ ] Moov API connection works
- [ ] Firebase Functions are deployed
- [ ] Google Pay configuration is complete
- [ ] Apple Pay configuration is complete
- [ ] Webhook endpoints respond correctly
- [ ] Subscription flow works end-to-end
- [ ] Payment processing completes successfully

## Production Deployment

### Before Going Live

1. **Switch to Production API Keys**
   - Replace test API keys with production keys
   - Update `isProduction` flag in `moov_config.dart`
   - Set `testMode` to `false`

2. **Security Checklist**
   - Never commit API keys to version control
   - Use environment variables in production
   - Enable webhook signature verification
   - Implement proper error handling

3. **Monitoring Setup**
   - Set up logging for payment events
   - Monitor webhook delivery status
   - Track payment success/failure rates
   - Set up alerts for payment issues

## Support

If you encounter issues:

1. Check [Moov Documentation](https://docs.moov.io)
2. Review [Google Pay Documentation](https://developers.google.com/pay)
3. Check [Apple Pay Documentation](https://developer.apple.com/apple-pay/)
4. Contact Moov Support for API-related issues