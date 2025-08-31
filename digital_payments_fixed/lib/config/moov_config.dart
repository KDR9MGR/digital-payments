class MoovConfig {
  // Moov API credentials - Use environment variables in production
  static String get apiKey => const String.fromEnvironment('MOOV_API_KEY', defaultValue: 'stGOlQhih6BdxYhV');
  static const String baseUrl = 'https://api.moov.io';
  static const bool isProduction = true;
  static const bool testMode = false;
  
  // Subscription details
  static const Map<String, Map<String, dynamic>> subscriptionPlans = {
    'super_payments': {
      'id': 'super_payments_monthly',
      'name': 'Super Payments',
      'description': 'Get Coupons, Brand Deals and Discounts on various brands and purchase Terms & Condition Apply',
      'price': 1.99,
      'currency': 'USD',
      'interval': 'month',
      'features': [
        'Get Coupons and Brand Deals',
        'Discounts on various brands',
        'Special purchase offers',
        'Priority customer support',
        'Enhanced transaction features',
        'Premium payment methods',
        'Advanced security features',
        'Real-time notifications',
      ],
    },
  };
  
  // Google Pay configuration
  static const Map<String, dynamic> googlePayConfig = {
    'environment': 'PRODUCTION',
    'apiVersion': 2,
    'apiVersionMinor': 0,
    'allowedPaymentMethods': [
      {
        'type': 'CARD',
        'parameters': {
          'allowedAuthMethods': ['PAN_ONLY', 'CRYPTOGRAM_3DS'],
          'allowedCardNetworks': ['AMEX', 'DISCOVER', 'JCB', 'MASTERCARD', 'VISA']
        },
        'tokenizationSpecification': {
          'type': 'PAYMENT_GATEWAY',
          'parameters': {
            'gateway': 'moov',
            'gatewayMerchantId': String.fromEnvironment('MOOV_MERCHANT_ID')
          }
        }
      }
    ],
    'merchantInfo': {
      'merchantId': String.fromEnvironment('GOOGLE_PAY_MERCHANT_ID'),
      'merchantName': 'XPay Digital Payments'
    }
  };
  
  // Apple Pay configuration
  static const Map<String, dynamic> applePayConfig = {
    'merchantIdentifier': String.fromEnvironment('APPLE_PAY_MERCHANT_ID', defaultValue: 'merchant.com.getdigitalpayments.xpay'),
    'displayName': 'XPay Digital Payments',
    'countryCode': 'US',
    'currencyCode': 'USD',
    'supportedNetworks': ['visa', 'masterCard', 'amex', 'discover'],
    'merchantCapabilities': ['3DS', 'debit', 'credit']
  };
} 