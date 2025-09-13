import '/utils/app_logger.dart';

class MoovConfig {
  // Moov API credentials - Use environment variables in production
  static String get apiKey {
    const envKey = String.fromEnvironment('MOOV_API_KEY', defaultValue: '');
    const defaultKey = 'cgM_7LhWXrGeFoEh'; // Production API key
    
    if (envKey.isNotEmpty) {
      AppLogger.log('Using environment MOOV_API_KEY');
      return envKey;
    } else {
      AppLogger.log('Using production MOOV_API_KEY');
      return defaultKey;
    }
  }
  
  static const String baseUrl = 'https://api.moov.io';
  static const String sandboxUrl = 'https://api.sandbox.moov.io';
  
  // Environment configuration
  static const bool isProduction = bool.fromEnvironment('MOOV_PRODUCTION', defaultValue: true);
  static const bool testMode = bool.fromEnvironment('MOOV_TEST_MODE', defaultValue: false);
  
  // Get the appropriate base URL based on environment
  static String get effectiveBaseUrl => isProduction ? baseUrl : sandboxUrl;
  
  // Webhook configuration
  static const String webhookSecret = String.fromEnvironment('MOOV_WEBHOOK_SECRET', defaultValue: 'default_webhook_secret');
  
  // Rate limiting configuration
  static const int maxTransfersPerDay = 10;
  static const Duration retryDelay = Duration(seconds: 2);
  static const int maxRetries = 3;
  
  // Transfer amount limits
  static const double minTransferAmount = 1.0;
  static const double maxTransferAmount = 10000.0;
  
  // Validate Moov configuration
  static bool get isConfigured {
    final key = apiKey;
    final isValid = key.isNotEmpty && key != 'your_moov_api_key_here' && key != 'stGOlQhih6BdxYhV';
    if (!isValid) {
      AppLogger.log('Error: Moov API key is not properly configured for production');
    }
    return isValid;
  }
  
  // Production readiness check
  static bool get isProductionReady {
    if (isProduction) {
      return isConfigured && 
             webhookSecret != 'default_webhook_secret' &&
             !testMode;
    }
    return true; // Always ready for development/testing
  }
  
  // Get environment status
  static String get environmentStatus {
    if (isProduction && isProductionReady) return 'Production';
    if (isProduction && !isProductionReady) return 'Production (Not Ready)';
    if (testMode) return 'Test Mode';
    return 'Development';
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