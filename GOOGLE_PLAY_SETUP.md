# Google Play API Configuration Guide

This guide will help you configure Google Play API access for subscription validation in your Firebase project.

## Step 1: Create Service Account in Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project (or create a new one)
3. Navigate to **IAM & Admin** > **Service Accounts**
4. Click **Create Service Account**
5. Fill in the details:
   - **Service account name**: `google-play-validator`
   - **Service account ID**: `google-play-validator`
   - **Description**: `Service account for Google Play subscription validation`
6. Click **Create and Continue**
7. Skip role assignment for now (we'll configure this in Google Play Console)
8. Click **Done**

## Step 2: Generate Service Account Key

1. In the Service Accounts list, click on the newly created service account
2. Go to the **Keys** tab
3. Click **Add Key** > **Create new key**
4. Select **JSON** format
5. Click **Create** - this will download the JSON key file
6. **IMPORTANT**: Keep this file secure and never commit it to version control

## Step 3: Enable Google Play Developer API

1. In Google Cloud Console, go to **APIs & Services** > **Library**
2. Search for "Google Play Developer API"
3. Click on it and press **Enable**

## Step 4: Configure Google Play Console

1. Go to [Google Play Console](https://play.google.com/console/)
2. Navigate to **Setup** > **API access**
3. If you haven't linked a Google Cloud project yet:
   - Click **Link** and select your Firebase project
4. In the **Service accounts** section, find your service account
5. Click **Grant access** next to your service account
6. Configure permissions:
   - **View financial data**: ✅ (Required for subscription validation)
   - **View app information and download bulk reports**: ✅ (Recommended)
   - **Manage orders and subscriptions**: ✅ (Required for subscription management)
7. Click **Invite user**

## Step 5: Configure Firebase Functions

You have two options for configuring the service account credentials:

### Option A: Using Firebase Config (Recommended for development)

```bash
# Extract values from your downloaded JSON key file
firebase functions:config:set googleplay.package_name="com.yourapp.package"
firebase functions:config:set googleplay.project_id="your-google-cloud-project-id"
firebase functions:config:set googleplay.private_key_id="your-private-key-id"
firebase functions:config:set googleplay.private_key="-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY_CONTENT\n-----END PRIVATE KEY-----"
firebase functions:config:set googleplay.client_email="your-service-account@your-project.iam.gserviceaccount.com"
firebase functions:config:set googleplay.client_id="your-client-id"
firebase functions:config:set googleplay.client_x509_cert_url="https://www.googleapis.com/robot/v1/metadata/x509/your-service-account%40your-project.iam.gserviceaccount.com"
```

### Option B: Using Environment Variable (Recommended for production)

```bash
# Set the path to your service account JSON file
firebase functions:config:set googleplay.service_account_path="/path/to/service-account.json"
```

## Step 6: Set Up Real-time Developer Notifications (Optional but Recommended)

1. In Google Cloud Console, go to **Pub/Sub** > **Topics**
2. Create a new topic: `google-play-notifications`
3. In Google Play Console, go to **Setup** > **API access**
4. Scroll down to **Real-time developer notifications**
5. Enter the topic name: `projects/your-project-id/topics/google-play-notifications`
6. Click **Save changes**

## Step 7: Test Configuration

Create a test script to verify your configuration:

```javascript
const { google } = require('googleapis');

// Test function
async function testGooglePlayAPI() {
  try {
    const auth = new google.auth.GoogleAuth({
      keyFile: 'path/to/service-account.json', // or use environment variables
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
    
    const androidpublisher = google.androidpublisher({
      version: 'v3',
      auth: auth,
    });
    
    // Test API access
    const response = await androidpublisher.applications.get({
      packageName: 'com.yourapp.package',
    });
    
    console.log('✅ Google Play API configuration successful!');
    console.log('App info:', response.data);
  } catch (error) {
    console.error('❌ Google Play API configuration failed:', error.message);
  }
}

testGooglePlayAPI();
```

## Step 8: Deploy and Test

1. Deploy your Firebase Functions:
   ```bash
   firebase deploy --only functions
   ```

2. Test subscription validation with a real purchase token from your app

## Security Best Practices

1. **Never commit service account keys to version control**
2. **Use Firebase Functions config or environment variables**
3. **Regularly rotate service account keys**
4. **Monitor API usage in Google Cloud Console**
5. **Set up alerts for unusual API activity**

## Troubleshooting

### Common Errors

1. **"The current user has insufficient permissions"**
   - Ensure service account has "View financial data" permission in Google Play Console

2. **"Invalid package name"**
   - Verify package name matches exactly with your app's package name

3. **"Invalid purchase token"**
   - Ensure you're using a real purchase token from Google Play Billing
   - Test tokens don't work with the production API

4. **"Authentication failed"**
   - Check service account JSON file is valid
   - Verify Google Play Developer API is enabled

### Testing with Sandbox

1. Add yourself as a license tester in Google Play Console
2. Upload your app to Internal Testing track
3. Install the app from the Play Store (not sideloaded)
4. Make a test purchase
5. Use the real purchase token for validation

## Next Steps

After completing this setup:
1. Test subscription validation in your app
2. Set up webhook endpoints for real-time notifications
3. Implement proper error handling and retry logic
4. Monitor subscription analytics and metrics