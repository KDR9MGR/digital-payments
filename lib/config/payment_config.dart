class PaymentConfig {
  // Google Pay Configuration
  static const Map<String, dynamic> googlePayConfig = {
    'environment': 'TEST', // 'TEST' or 'PRODUCTION'
    'apiVersion': 2,
    'apiVersionMinor': 0,
    'merchantInfo': {
      'merchantName': 'XPay Digital Payments',
      'merchantId': 'your-google-pay-merchant-id',
    },
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
            'gateway': 'stripe',
            'gatewayMerchantId': 'your-stripe-merchant-id'
          }
        }
      }
    ]
  };

  // Apple Pay Configuration
  static const Map<String, dynamic> applePayConfig = {
    'merchantIdentifier': 'merchant.com.digitalpayments.xpay',
    'displayName': 'XPay Digital Payments',
    'countryCode': 'US',
    'currencyCode': 'USD',
    'supportedNetworks': ['visa', 'masterCard', 'amex', 'discover'],
    'merchantCapabilities': ['3DS', 'debit', 'credit'],
  };

  // Payment processing configuration
  static const Map<String, dynamic> processingConfig = {
    'defaultCurrency': 'USD',
    'supportedCurrencies': ['USD', 'EUR', 'GBP'],
    'maxTransactionAmount': 10000.00,
    'minTransactionAmount': 0.50,
  };
}