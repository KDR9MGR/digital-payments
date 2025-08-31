import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_logger.dart';

/// Service for server-side purchase validation and receipt verification
class PurchaseValidationService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Apple App Store validation URLs
  static const String _appleProductionUrl = 'https://buy.itunes.apple.com/verifyReceipt';
  static const String _appleSandboxUrl = 'https://sandbox.itunes.apple.com/verifyReceipt';
  
  /// Validate Google Play Store purchase with Firebase Functions
  static Future<ValidationResult> validateGooglePlayPurchase({
    required String purchaseToken,
    required String productId,
    required String packageName,
  }) async {
    try {
      AppLogger.log('Validating Google Play purchase for product: $productId');
      
      final callable = _functions.httpsCallable('validateGooglePlayPurchaseReal');
      
      final result = await callable.call({
        'purchaseToken': purchaseToken,
        'productId': productId,
        'packageName': packageName,
      });
      
      final data = result.data as Map<String, dynamic>;
      
      if (data['success'] == true) {
        return ValidationResult(
          isValid: true,
          transactionId: data['subscriptionId'],
          expiryDate: data['expiryDate'] != null 
              ? DateTime.parse(data['expiryDate'])
              : null,
        );
      } else {
        return ValidationResult(
          isValid: false,
          errorMessage: data['message'] ?? 'Google Play validation failed',
        );
      }
    } catch (e) {
      AppLogger.log('Error validating Google Play purchase: $e');
      return ValidationResult(
        isValid: false,
        errorMessage: 'Google Play validation error: $e',
      );
    }
  }
  
  /// Validate Apple App Store purchase with Firebase Functions
  static Future<ValidationResult> validateAppleStorePurchase({
    required String receiptData,
    required String productId,
  }) async {
    try {
      AppLogger.log('Validating Apple Store purchase for product: $productId');
      
      final callable = _functions.httpsCallable('validateApplePayPurchaseReal');
      
      final result = await callable.call({
        'receiptData': receiptData,
        'productId': productId,
      });
      
      final data = result.data as Map<String, dynamic>;
      
      if (data['success'] == true) {
        return ValidationResult(
          isValid: true,
          transactionId: data['subscriptionId'],
          expiryDate: data['expiryDate'] != null 
              ? DateTime.parse(data['expiryDate'])
              : null,
        );
      } else {
        return ValidationResult(
          isValid: false,
          errorMessage: data['message'] ?? 'Apple Store validation failed',
        );
      }
    } catch (e) {
      AppLogger.log('Error validating Apple Store purchase: $e');
      return ValidationResult(
        isValid: false,
        errorMessage: 'Apple Store validation error: $e',
      );
    }
  }
  
  /// Validate purchase receipt with Firebase Functions (unified method)
  /// This is the recommended approach for production apps
  static Future<ValidationResult> validatePurchaseWithServer({
    required String receiptData,
    required String productId,
    required String userId,
    required String platform,
    String? purchaseToken,
    String? packageName,
  }) async {
    try {
      if (platform.toLowerCase() == 'android' && purchaseToken != null) {
        return await validateGooglePlayPurchase(
          purchaseToken: purchaseToken,
          productId: productId,
          packageName: packageName ?? 'com.yourapp.package',
        );
      } else if (platform.toLowerCase() == 'ios') {
        return await validateAppleStorePurchase(
          receiptData: receiptData,
          productId: productId,
        );
      } else {
        return ValidationResult(
          isValid: false,
          errorMessage: 'Unsupported platform: $platform',
        );
      }
    } catch (e) {
      AppLogger.log('Error validating purchase with server: $e');
      return ValidationResult(
        isValid: false,
        errorMessage: 'Purchase validation error: $e',
      );
    }
  }
  
  /// Get current subscription status from Firebase Functions
  static Future<SubscriptionStatus> getSubscriptionStatus(String userId) async {
    try {
      AppLogger.log('Fetching subscription status for user: $userId');
      
      final callable = _functions.httpsCallable('checkSubscriptionStatus');
      
      final result = await callable.call({
        'userId': userId,
      });
      
      final data = result.data as Map<String, dynamic>;
      
      return SubscriptionStatus(
        isActive: data['subscriptionStatus'] == 'active',
        expiryDate: data['expiryDate'] != null 
            ? DateTime.parse(data['expiryDate'])
            : null,
        productId: data['planType'],
        isInGracePeriod: data['isInGracePeriod'] ?? false,
      );
    } catch (e) {
      AppLogger.log('Error fetching subscription status: $e');
      return SubscriptionStatus(
        isActive: false,
        expiryDate: null,
      );
    }
  }
  
  /// Direct Apple App Store receipt validation (fallback method)
  /// Note: This should only be used as a fallback. Server-side validation is preferred.
  static Future<ValidationResult> validateAppleReceipt({
    required String receiptData,
    required String sharedSecret,
    bool useSandbox = false,
  }) async {
    try {
      AppLogger.log('Validating Apple receipt directly');
      
      final url = useSandbox ? _appleSandboxUrl : _appleProductionUrl;
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'receipt-data': receiptData,
          'password': sharedSecret,
          'exclude-old-transactions': true,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'] as int;
        
        if (status == 0) {
          // Receipt is valid
          return ValidationResult(
            isValid: true,
            receiptData: data,
          );
        } else if (status == 21007 && !useSandbox) {
          // Receipt is from sandbox, retry with sandbox URL
          return validateAppleReceipt(
            receiptData: receiptData,
            sharedSecret: sharedSecret,
            useSandbox: true,
          );
        } else {
          return ValidationResult(
            isValid: false,
            errorMessage: 'Apple validation failed with status: $status',
          );
        }
      } else {
        return ValidationResult(
          isValid: false,
          errorMessage: 'Apple validation request failed',
        );
      }
    } catch (e) {
      AppLogger.log('Error validating Apple receipt: $e');
      return ValidationResult(
        isValid: false,
        errorMessage: 'Apple validation error: $e',
      );
    }
  }
  
  /// Get current Firebase Auth user token
  static Future<String?> _getAuthToken() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        return await user.getIdToken();
      }
      return null;
    } catch (e) {
      AppLogger.log('Error getting auth token: $e');
      return null;
    }
  }
}

/// Platform enum for validation
enum Platform {
  iOS,
  android,
}

/// Validation result model
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final Map<String, dynamic>? receiptData;
  final DateTime? expiryDate;
  final String? transactionId;
  
  ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.receiptData,
    this.expiryDate,
    this.transactionId,
  });
  
  factory ValidationResult.fromJson(Map<String, dynamic> json) {
    return ValidationResult(
      isValid: json['is_valid'] ?? false,
      errorMessage: json['error_message'],
      receiptData: json['receipt_data'],
      expiryDate: json['expiry_date'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['expiry_date'])
          : null,
      transactionId: json['transaction_id'],
    );
  }
}

/// Subscription status model
class SubscriptionStatus {
  final bool isActive;
  final DateTime? expiryDate;
  final String? productId;
  final String? transactionId;
  final bool isInGracePeriod;
  final bool isInTrialPeriod;
  
  SubscriptionStatus({
    required this.isActive,
    this.expiryDate,
    this.productId,
    this.transactionId,
    this.isInGracePeriod = false,
    this.isInTrialPeriod = false,
  });
  
  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      isActive: json['is_active'] ?? false,
      expiryDate: json['expiry_date'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['expiry_date'])
          : null,
      productId: json['product_id'],
      transactionId: json['transaction_id'],
      isInGracePeriod: json['is_in_grace_period'] ?? false,
      isInTrialPeriod: json['is_in_trial_period'] ?? false,
    );
  }
  
  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }
  
  bool get isValidSubscription {
    return isActive && !isExpired;
  }
}