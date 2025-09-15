# Moov Credentials Setup Guide

## Current Issue
The transfer error occurs because Moov OAuth2 credentials are not configured in Firebase Functions. The code is correctly implemented but missing the required environment variables.

## Required Credentials

Moov uses OAuth2 client credentials flow for authentication. You need to obtain these from your Moov Dashboard:

### 1. Moov Dashboard Credentials
- **Public Key** (`moov.public_key`)
- **Private Key** (`moov.private_key`) 
- **Client ID** (`moov.client_id`)
- **Client Secret** (`moov.client_secret`)
- **Platform Account ID** (`moov.platform_account_id`)

## How to Get Credentials

### Step 1: Access Moov Dashboard
1. Go to [Moov Dashboard](https://dashboard.moov.io)
2. Log in to your business account
3. Navigate to **API Keys** or **Credentials** section

### Step 2: Generate OAuth2 Credentials
1. Create a new API application if you haven't already
2. Note down the **Client ID** and **Client Secret**
3. Generate or locate your **Public Key** and **Private Key**
4. Find your **Platform Account ID** (this is your main business account ID)

### Step 3: Configure Firebase Functions
Run these commands to set the credentials:

```bash
# Set Moov credentials in Firebase Functions config
firebase functions:config:set moov.public_key="your_public_key_here"
firebase functions:config:set moov.private_key="your_private_key_here"
firebase functions:config:set moov.client_id="your_client_id_here"
firebase functions:config:set moov.client_secret="your_client_secret_here"
firebase functions:config:set moov.platform_account_id="your_platform_account_id_here"

# Optional: Set base URL (defaults to production)
firebase functions:config:set moov.base_url="https://api.moov.io"

# Deploy the functions with new config
firebase deploy --only functions
```

### Step 4: Verify Configuration
Check that credentials are set:
```bash
firebase functions:config:get
```

## Security Notes

- **Never commit credentials to version control**
- Use different credentials for development/staging vs production
- Regularly rotate your API keys
- Monitor API usage in Moov Dashboard

## Testing

After setting up credentials:
1. Try a small transfer in the app
2. Check Firebase Functions logs for any authentication errors
3. Verify transfers appear in Moov Dashboard

## Troubleshooting

### Common Issues:
1. **401 Unauthorized**: Check client_id and client_secret
2. **403 Forbidden**: Verify account permissions and KYB status
3. **Invalid credentials**: Ensure keys are copied correctly without extra spaces

### Debug Steps:
1. Check Firebase Functions logs: `firebase functions:log`
2. Verify config: `firebase functions:config:get`
3. Test OAuth2 token generation in Moov Dashboard API explorer