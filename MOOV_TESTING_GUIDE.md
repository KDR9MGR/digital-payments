# Moov Payment Testing Guide

This guide provides step-by-step instructions for testing Moov payment functionality in the XPay Flutter app.

## Prerequisites

✅ Flutter app is running on device/emulator  
✅ Environment variables are configured  
✅ Firebase Functions are deployed  
✅ Moov API credentials are valid  

## Testing Checklist

### 1. Configuration Validation ✅

**Status**: Completed
- [x] Run validation script: `dart validate_moov_payments.dart`
- [x] Configuration files present
- [x] Firebase Functions deployed
- [ ] Environment variables configured
- [ ] API connectivity working

### 2. UI Testing

#### 2.1 Subscription Screen Access

**Steps to Test:**
1. Launch the Flutter app
2. Navigate to Settings or Profile section
3. Look for "Premium Subscription" or "Subscription" option
4. Tap to open subscription screen

**Expected Results:**
- Subscription screen loads without errors
- Subscription plans are displayed
- Google Pay and Apple Pay buttons are visible
- Pricing information is correct ($1.99/month)

#### 2.2 Payment Button Interactions

**Google Pay Button Test:**
1. Tap on "Pay with Google Pay" button
2. Observe button response and loading states
3. Check console logs for any errors

**Apple Pay Button Test:**
1. Tap on "Pay with Apple Pay" button
2. Observe button response and loading states
3. Check console logs for any errors

**Expected Results:**
- Buttons respond to taps
- Loading indicators appear
- No immediate crashes or errors
- Appropriate error messages if payment methods unavailable

### 3. Google Pay Flow Testing

#### 3.1 Android Device/Emulator Testing

**Prerequisites:**
- Google Play Services installed
- Google Pay app installed (or available)
- Test Google account signed in

**Test Steps:**
1. Navigate to subscription screen
2. Tap "Pay with Google Pay" button
3. Observe Google Pay sheet presentation
4. Test with test payment method
5. Complete or cancel payment flow

**Expected Results:**
- Google Pay sheet opens
- Payment methods are displayed
- Test payment completes successfully
- Success/failure feedback is shown
- Subscription status updates correctly

**Common Issues:**
- "Google Pay not available" error
- Missing Google Play Services
- Invalid merchant configuration
- Network connectivity issues

### 4. Apple Pay Flow Testing

#### 4.1 iOS Device/Simulator Testing

**Prerequisites:**
- iOS device with Touch ID/Face ID or Simulator
- Apple Pay configured with test cards
- Valid Apple Pay merchant certificate

**Test Steps:**
1. Navigate to subscription screen
2. Tap "Pay with Apple Pay" button
3. Observe Apple Pay sheet presentation
4. Authenticate with Touch ID/Face ID
5. Complete or cancel payment flow

**Expected Results:**
- Apple Pay sheet opens
- Payment methods are displayed
- Authentication works correctly
- Test payment completes successfully
- Success/failure feedback is shown
- Subscription status updates correctly

**Common Issues:**
- "Apple Pay not available" error
- Missing merchant certificate
- Invalid merchant identifier
- Device doesn't support Apple Pay

### 5. Backend Integration Testing

#### 5.1 Firebase Functions Testing

**Test Webhook Endpoint:**
```bash
# Test moovWebhook function
curl -X POST https://your-project.cloudfunctions.net/moovWebhook \
  -H "Content-Type: application/json" \
  -d '{
    "type": "account.created",
    "data": {
      "accountID": "test_account_123",
      "status": "active"
    }
  }'
```

**Test Account Creation:**
```bash
# Test createMoovAccount function
curl -X POST https://your-project.cloudfunctions.net/createMoovAccount \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "email": "test@example.com",
      "firstName": "Test",
      "lastName": "User",
      "userId": "test_user_123"
    }
  }'
```

**Test Subscription Processing:**
```bash
# Test processMoovSubscription function
curl -X POST https://your-project.cloudfunctions.net/processMoovSubscription \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "userId": "test_user_123",
      "planId": "super_payments_monthly",
      "paymentMethodId": "test_payment_method"
    }
  }'
```

#### 5.2 Moov API Direct Testing

**Test API Connection:**
```bash
# Test Moov API ping
curl -X GET https://api.moov.io/ping \
  -H "Authorization: Bearer $MOOV_API_KEY"
```

**Test Account Creation:**
```bash
# Create test account
curl -X POST https://api.moov.io/accounts \
  -H "Authorization: Bearer $MOOV_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "accountType": "individual",
    "profile": {
      "individual": {
        "name": {
          "firstName": "Test",
          "lastName": "User"
        },
        "email": "test@example.com"
      }
    }
  }'
```

### 6. Error Handling Testing

#### 6.1 Network Error Scenarios

**Test Cases:**
1. **No Internet Connection**
   - Disable network connectivity
   - Attempt payment flow
   - Verify appropriate error messages

2. **API Server Down**
   - Use invalid API endpoint
   - Attempt payment flow
   - Verify graceful error handling

3. **Invalid API Key**
   - Use expired/invalid API key
   - Attempt payment flow
   - Verify authentication error handling

#### 6.2 Payment Method Error Scenarios

**Test Cases:**
1. **Insufficient Funds**
   - Use test card with insufficient funds
   - Complete payment flow
   - Verify error message and retry options

2. **Declined Card**
   - Use test card that gets declined
   - Complete payment flow
   - Verify appropriate error handling

3. **Expired Card**
   - Use test card with expired date
   - Complete payment flow
   - Verify validation and error messages

### 7. User Experience Testing

#### 7.1 Loading States

**Test Points:**
- Payment button shows loading indicator
- Subscription screen shows loading during API calls
- Appropriate timeouts are implemented
- User can cancel long-running operations

#### 7.2 Success/Failure Feedback

**Test Points:**
- Success messages are clear and informative
- Error messages are user-friendly
- Retry mechanisms are available
- Navigation after payment completion works

#### 7.3 Subscription Status

**Test Points:**
- Subscription status updates in real-time
- Premium features are unlocked after payment
- Subscription expiry is handled correctly
- Renewal notifications work properly

### 8. Security Testing

#### 8.1 Data Protection

**Test Points:**
- Payment data is not logged in plain text
- API keys are not exposed in client code
- Sensitive data is encrypted in transit
- User payment information is handled securely

#### 8.2 Authentication

**Test Points:**
- API requests include proper authentication
- Webhook endpoints verify request signatures
- User sessions are managed securely
- Payment flows require proper user authentication

### 9. Performance Testing

#### 9.1 Response Times

**Test Points:**
- Payment button response time < 1 second
- API calls complete within reasonable time
- UI remains responsive during payment flows
- Large payment histories load efficiently

#### 9.2 Memory Usage

**Test Points:**
- No memory leaks during payment flows
- App performance remains stable
- Background payment processing doesn't impact UI

### 10. Cross-Platform Testing

#### 10.1 Android Testing

**Test Devices:**
- Android emulator (API 30+)
- Physical Android device
- Different Android versions
- Various screen sizes

#### 10.2 iOS Testing

**Test Devices:**
- iOS Simulator
- Physical iOS device
- Different iOS versions
- Various screen sizes

### 11. Production Readiness Checklist

**Before Going Live:**
- [ ] All test cases pass
- [ ] Production API keys configured
- [ ] Environment variables set correctly
- [ ] Firebase Functions deployed to production
- [ ] Webhook endpoints are accessible
- [ ] SSL certificates are valid
- [ ] Error monitoring is set up
- [ ] Payment analytics are configured
- [ ] Customer support processes are ready
- [ ] Refund/cancellation flows are tested

## Test Results Template

### Test Execution Summary

**Date**: ___________  
**Tester**: ___________  
**Environment**: ___________  
**App Version**: ___________  

| Test Category | Status | Notes |
|---------------|-----------|-------|
| Configuration Validation | ✅/❌ | |
| UI Testing | ✅/❌ | |
| Google Pay Flow | ✅/❌ | |
| Apple Pay Flow | ✅/❌ | |
| Backend Integration | ✅/❌ | |
| Error Handling | ✅/❌ | |
| User Experience | ✅/❌ | |
| Security | ✅/❌ | |
| Performance | ✅/❌ | |
| Cross-Platform | ✅/❌ | |

**Overall Status**: ✅ Ready for Production / ❌ Needs Fixes

**Critical Issues Found**:
1. 
2. 
3. 

**Recommendations**:
1. 
2. 
3. 

## Troubleshooting Common Issues

### Issue: Google Pay Not Available
**Solution**: 
- Check Google Play Services installation
- Verify Google Pay app is installed
- Ensure device supports Google Pay
- Check merchant configuration

### Issue: Apple Pay Not Available
**Solution**:
- Verify device supports Apple Pay
- Check Apple Pay setup in Settings
- Validate merchant certificate
- Ensure proper entitlements

### Issue: API Authentication Failures
**Solution**:
- Verify API key is correct and active
- Check environment variable configuration
- Validate API key permissions
- Test API connection directly

### Issue: Payment Processing Failures
**Solution**:
- Check network connectivity
- Verify payment method validity
- Review Firebase Function logs
- Test with different payment methods

### Issue: Webhook Not Receiving Events
**Solution**:
- Verify webhook URL is accessible
- Check Moov dashboard webhook configuration
- Review Firebase Function deployment
- Test webhook endpoint manually

## Support Resources

- [Moov API Documentation](https://docs.moov.io)
- [Google Pay Documentation](https://developers.google.com/pay)
- [Apple Pay Documentation](https://developer.apple.com/apple-pay/)
- [Firebase Functions Documentation](https://firebase.google.com/docs/functions)