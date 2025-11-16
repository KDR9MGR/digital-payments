import 'dart:io';
import 'package:flutter/foundation.dart';
import '/utils/app_logger.dart';

class PlaidConfig {
  // Plaid API credentials - Use environment variables in production
  static String get clientId {
    const envClientId = String.fromEnvironment('PLAID_CLIENT_ID', defaultValue: '');
    const defaultClientId = 'your_plaid_client_id_here'; // Sandbox client ID
    
    if (envClientId.isNotEmpty) {
      AppLogger.log('Using environment PLAID_CLIENT_ID');
      return envClientId;
    } else {
      AppLogger.log('Using default PLAID_CLIENT_ID');
      return defaultClientId;
    }
  }
  
  static String get secret {
    const envSecret = String.fromEnvironment('PLAID_SECRET', defaultValue: '');
    const defaultSecret = 'your_plaid_secret_here'; // Sandbox secret
    
    if (envSecret.isNotEmpty) {
      AppLogger.log('Using environment PLAID_SECRET');
      return envSecret;
    } else {
      AppLogger.log('Using default PLAID_SECRET');
      return defaultSecret;
    }
  }
  
  static String get publicKey {
    const envPublicKey = String.fromEnvironment('PLAID_PUBLIC_KEY', defaultValue: '');
    const defaultPublicKey = 'your_plaid_public_key_here'; // Sandbox public key
    
    if (envPublicKey.isNotEmpty) {
      AppLogger.log('Using environment PLAID_PUBLIC_KEY');
      return envPublicKey;
    } else {
      AppLogger.log('Using default PLAID_PUBLIC_KEY');
      return defaultPublicKey;
    }
  }
  
  // Environment configuration - Set to sandbox for development
  static const String environment = String.fromEnvironment('PLAID_ENVIRONMENT', defaultValue: 'sandbox');
  static const bool isProduction = bool.fromEnvironment('PLAID_PRODUCTION', defaultValue: false);
  static const bool testMode = bool.fromEnvironment('PLAID_TEST_MODE', defaultValue: true);
  
  // Plaid products to use
  static const List<String> products = ['auth', 'transactions', 'identity'];
  static const List<String> countryCodes = ['US'];
  
  // Backend API configuration
  static String get backendBaseUrl {
    const envUrl = String.fromEnvironment('BACKEND_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    
    if (kIsWeb) {
      return 'http://localhost:8080';
    } else if (Platform.isAndroid) {
      // For Android emulator, use 10.0.2.2 to reach host machine
      return 'http://10.0.2.2:8080';
    } else {
      // For iOS simulator and other platforms
      return 'http://localhost:8080';
    }
  }
  
  // Webhook configuration
  static const String webhookSecret = String.fromEnvironment('PLAID_WEBHOOK_SECRET', defaultValue: 'default_webhook_secret');
  
  // Rate limiting configuration
  static const int maxTransfersPerDay = 10;
  static const Duration retryDelay = Duration(seconds: 2);
  static const int maxRetries = 3;
  
  // Transfer amount limits
  static const double minTransferAmount = 1.0;
  static const double maxTransferAmount = 10000.0;
  
  // Validate Plaid configuration
  static bool get isConfigured {
    final client = clientId;
    final sec = secret;
    final pub = publicKey;
    final isValid = client.isNotEmpty && 
                   client != 'your_plaid_client_id_here' && 
                   sec.isNotEmpty &&
                   sec != 'your_plaid_secret_here' &&
                   pub.isNotEmpty &&
                   pub != 'your_plaid_public_key_here';
    if (!isValid) {
      AppLogger.log('Error: Plaid configuration is not properly set for production');
    }
    return isValid;
  }
  
  // Production readiness check
  static bool get isProductionReady {
    if (isProduction) {
      return isConfigured && 
             webhookSecret != 'default_webhook_secret' &&
             environment == 'production' &&
             !testMode;
    }
    return true; // Always ready for development/testing
  }
  
  // Get environment status
  static String get environmentStatus {
    if (isProduction && isProductionReady) return 'Production';
    if (isProduction && !isProductionReady) return 'Production (Not Ready)';
    if (testMode) return 'Test Mode';
    return 'Development ($environment)';
  }
  
  // Backend API endpoints
  static const String createLinkTokenEndpoint = '/plaid/link-token';
  static const String exchangeTokenEndpoint = '/plaid/exchange-token';
  static const String getAccountsEndpoint = '/plaid/accounts';
  static const String getAuthEndpoint = '/plaid/auth';
  static const String getTransactionsEndpoint = '/plaid/transactions';
  static const String getBalanceEndpoint = '/plaid/balance';
  static const String createTransferEndpoint = '/plaid/transfer';
  static const String webhookEndpoint = '/plaid/webhook';
  
  // Plaid Link configuration
  static Map<String, dynamic> get linkConfiguration => {
    'clientName': 'XPay Money Transfer',
    'products': products,
    'countryCodes': countryCodes,
    'language': 'en',
    'environment': environment,
    'clientId': clientId,
    'publicKey': publicKey,
  };
  
  // Payment processor configuration (for actual money movement)
  static const String paymentProcessor = String.fromEnvironment('PAYMENT_PROCESSOR', defaultValue: 'dwolla');
  static const String processorEnvironment = String.fromEnvironment('PROCESSOR_ENVIRONMENT', defaultValue: 'sandbox');
  
  // Security configuration
  static const String encryptionKey = String.fromEnvironment('ENCRYPTION_KEY', defaultValue: 'default_encryption_key_change_in_production');
  static const Duration tokenExpiryDuration = Duration(hours: 24);
  
  // User consent and compliance
  static const String privacyPolicyUrl = 'https://yourapp.com/privacy';
  static const String termsOfServiceUrl = 'https://yourapp.com/terms';
  static const String dataUsageDisclosure = 'We use Plaid to securely connect your bank account and verify your identity for P2P transfers.';
  
  // KYC and verification requirements
  static const bool requireKyc = true;
  static const bool requireAccountVerification = true;
  static const Duration verificationTimeout = Duration(minutes: 30);
  
  // Transaction monitoring
  static const double suspiciousAmountThreshold = 5000.0;
  static const int maxDailyTransactions = 20;
  static const double maxDailyTransferAmount = 25000.0;
  
  // Error handling configuration
  static const Map<String, String> errorMessages = {
    'ITEM_LOGIN_REQUIRED': 'Please reconnect your bank account',
    'INSUFFICIENT_FUNDS': 'Insufficient funds in your account',
    'ACCOUNT_LOCKED': 'Your account is temporarily locked',
    'INVALID_CREDENTIALS': 'Invalid bank credentials',
    'ITEM_NOT_FOUND': 'Bank account not found',
    'ACCESS_NOT_GRANTED': 'Access to account not granted',
    'INSTITUTION_DOWN': 'Bank is temporarily unavailable',
    'INSTITUTION_NOT_RESPONDING': 'Bank is not responding',
    'INVALID_REQUEST': 'Invalid request parameters',
    'RATE_LIMIT_EXCEEDED': 'Too many requests, please try again later',
  };
  
  // Logging configuration
  static const bool enableDetailedLogging = bool.fromEnvironment('PLAID_DETAILED_LOGGING', defaultValue: false);
  static const bool logSensitiveData = false; // Never log sensitive data in production
  
  // Cache configuration
  static const Duration accountCacheDuration = Duration(minutes: 15);
  static const Duration balanceCacheDuration = Duration(minutes: 5);
  static const Duration transactionCacheDuration = Duration(hours: 1);
}