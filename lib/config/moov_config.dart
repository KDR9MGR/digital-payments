import '/utils/app_logger.dart';

class MoovConfig {
  // Moov API credentials - Use environment variables in production
  static String get apiKey {
    const envKey = String.fromEnvironment('MOOV_API_KEY', defaultValue: '');
    const defaultKey = 'stGOlQhih6BdxYhV';
    
    if (envKey.isNotEmpty) {
      AppLogger.log('Using environment MOOV_API_KEY');
      return envKey;
    } else {
      AppLogger.log('Warning: Using default MOOV_API_KEY - set MOOV_API_KEY environment variable for production');
      return defaultKey;
    }
  }
  
  static const String baseUrl = 'https://api.moov.io';
  static const bool isProduction = false;
  static const bool testMode = true;
  
  // Validate Moov configuration
  static bool get isConfigured {
    final key = apiKey;
    final isValid = key.isNotEmpty && key != 'your_moov_api_key_here';
    if (!isValid) {
      AppLogger.log('Error: Moov API key is not properly configured');
    }
    return isValid;
  }
  
  // Note: Moov is used only for send/receive money functionality
  // Subscriptions are handled through in-app purchases only
  
  // Google Pay configuration for money transfers (not subscriptions)
  static const Map<String, dynamic> googlePayConfig = {
    'environment': 'TEST', // or 'PRODUCTION'
    'merchantInfo': {
      'merchantName': 'XPay Money Transfer',
      'merchantId': 'merchant.com.xpay.transfer',
    },
    'apiVersion': 2,
    'apiVersionMinor': 0,
    'allowedPaymentMethods': [
      {
        'type': 'CARD',
        'parameters': {
          'allowedAuthMethods': ['PAN_ONLY', 'CRYPTOGRAM_3DS'],
          'allowedCardNetworks': ['AMEX', 'DISCOVER', 'JCB', 'MASTERCARD', 'VISA']
        }
      }
    ],
  };
  
  // Apple Pay configuration for money transfers (not subscriptions)
  static const Map<String, dynamic> applePayConfig = {
    'displayName': 'XPay Money Transfer',
    'countryCode': 'US',
    'supportedNetworks': ['visa', 'mastercard', 'amex'],
    'merchantCapabilities': ['3DS', 'EMV'],
  };
}