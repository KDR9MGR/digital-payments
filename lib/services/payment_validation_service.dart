import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../utils/app_logger.dart';
import '../routes/routes.dart';
import 'firebase_batch_service.dart';
import 'firebase_query_optimizer.dart';

class PaymentValidationService {
  static const int _sessionTimeoutMinutes = 15; // 15 minutes session timeout
  static Timer? _sessionTimer;
  static DateTime? _lastActivity;
  static bool _isPaymentSessionActive = false;
  static final FirebaseBatchService _batchService = FirebaseBatchService();

  // Singleton pattern
  static final PaymentValidationService _instance =
      PaymentValidationService._internal();
  factory PaymentValidationService() => _instance;
  PaymentValidationService._internal();

  /// Start payment session with timeout
  static void startPaymentSession() {
    _isPaymentSessionActive = true;
    _lastActivity = DateTime.now();
    _startSessionTimer();
    AppLogger.log(
      'Payment session started with ${_sessionTimeoutMinutes}min timeout',
    );
  }

  /// End payment session
  static void endPaymentSession() {
    _isPaymentSessionActive = false;
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _lastActivity = null;
    AppLogger.log('Payment session ended');
  }

  /// Update last activity timestamp
  static void updateActivity() {
    if (_isPaymentSessionActive) {
      _lastActivity = DateTime.now();
    }
  }

  /// Check if payment session is still valid
  static bool isSessionValid() {
    if (!_isPaymentSessionActive || _lastActivity == null) {
      return false;
    }

    final now = DateTime.now();
    final timeDifference = now.difference(_lastActivity!);
    return timeDifference.inMinutes < _sessionTimeoutMinutes;
  }

  /// Start session timeout timer
  static void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      if (!isSessionValid()) {
        _handleSessionTimeout();
      }
    });
  }

  /// Handle session timeout
  static void _handleSessionTimeout() {
    AppLogger.log('Payment session timed out');
    endPaymentSession();

    Get.snackbar(
      'Session Expired',
      'Your payment session has expired for security reasons. Please try again.',
      snackPosition: SnackPosition.TOP,
      duration: Duration(seconds: 5),
    );

    // Navigate back to subscription screen
    Get.offAllNamed(Routes.subscriptionScreen);
  }

  /// Validate Google Pay payment
  static Future<Map<String, dynamic>> validateGooglePayPayment({
    required String transactionId,
    required double amount,
    required String currency,
    required String subscriptionId,
  }) async {
    try {
      updateActivity();

      if (!isSessionValid()) {
        return {
          'success': false,
          'error': 'Payment session expired',
          'errorCode': 'SESSION_EXPIRED',
        };
      }

      AppLogger.log('Validating Google Pay payment: $transactionId');

      // Validate user authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
          'errorCode': 'AUTH_REQUIRED',
        };
      }

      // Validate payment amount
      if (amount <= 0) {
        return {
          'success': false,
          'error': 'Invalid payment amount',
          'errorCode': 'INVALID_AMOUNT',
        };
      }

      // Validate currency
      if (!_isValidCurrency(currency)) {
        return {
          'success': false,
          'error': 'Unsupported currency',
          'errorCode': 'INVALID_CURRENCY',
        };
      }

      // Check for duplicate transactions
      final isDuplicate = await _checkDuplicateTransaction(
        transactionId,
        user.uid,
      );
      if (isDuplicate) {
        return {
          'success': false,
          'error': 'Duplicate transaction detected',
          'errorCode': 'DUPLICATE_TRANSACTION',
        };
      }

      // Store payment validation record
      await _storePaymentValidation({
        'transactionId': transactionId,
        'userId': user.uid,
        'amount': amount,
        'currency': currency,
        'subscriptionId': subscriptionId,
        'paymentMethod': 'google_pay',
        'status': 'validated',
        'timestamp': FieldValue.serverTimestamp(),
        'sessionId': _generateSessionId(),
      });

      AppLogger.log('Google Pay payment validated successfully');

      return {
        'success': true,
        'transactionId': transactionId,
        'validatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      AppLogger.error('Error validating Google Pay payment: $e');
      return {
        'success': false,
        'error': 'Payment validation failed',
        'errorCode': 'VALIDATION_ERROR',
      };
    }
  }

  /// Validate Apple Pay payment
  static Future<Map<String, dynamic>> validateApplePayPayment({
    required String transactionId,
    required double amount,
    required String currency,
    required String subscriptionId,
  }) async {
    try {
      updateActivity();

      if (!isSessionValid()) {
        return {
          'success': false,
          'error': 'Payment session expired',
          'errorCode': 'SESSION_EXPIRED',
        };
      }

      AppLogger.log('Validating Apple Pay payment: $transactionId');

      // Validate user authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
          'errorCode': 'AUTH_REQUIRED',
        };
      }

      // Validate payment amount
      if (amount <= 0) {
        return {
          'success': false,
          'error': 'Invalid payment amount',
          'errorCode': 'INVALID_AMOUNT',
        };
      }

      // Validate currency
      if (!_isValidCurrency(currency)) {
        return {
          'success': false,
          'error': 'Unsupported currency',
          'errorCode': 'INVALID_CURRENCY',
        };
      }

      // Check for duplicate transactions
      final isDuplicate = await _checkDuplicateTransaction(
        transactionId,
        user.uid,
      );
      if (isDuplicate) {
        return {
          'success': false,
          'error': 'Duplicate transaction detected',
          'errorCode': 'DUPLICATE_TRANSACTION',
        };
      }

      // Store payment validation record
      await _storePaymentValidation({
        'transactionId': transactionId,
        'userId': user.uid,
        'amount': amount,
        'currency': currency,
        'subscriptionId': subscriptionId,
        'paymentMethod': 'apple_pay',
        'status': 'validated',
        'timestamp': FieldValue.serverTimestamp(),
        'sessionId': _generateSessionId(),
      });

      AppLogger.log('Apple Pay payment validated successfully');

      return {
        'success': true,
        'transactionId': transactionId,
        'validatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      AppLogger.error('Error validating Apple Pay payment: $e');
      return {
        'success': false,
        'error': 'Payment validation failed',
        'errorCode': 'VALIDATION_ERROR',
      };
    }
  }

  /// Validate subscription purchase
  static Future<Map<String, dynamic>> validateSubscriptionPurchase({
    required String subscriptionId,
    required String planId,
    required double amount,
    required String paymentMethod,
  }) async {
    try {
      updateActivity();

      if (!isSessionValid()) {
        return {
          'success': false,
          'error': 'Payment session expired',
          'errorCode': 'SESSION_EXPIRED',
        };
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
          'errorCode': 'AUTH_REQUIRED',
        };
      }

      // PREMIUM ACCESS: All users now have premium access, no need to check existing subscription
      // Original subscription existence check (commented out)
      // final hasActiveSubscription = await _checkActiveSubscription(user.uid);
      // if (hasActiveSubscription) {
      //   return {
      //     'success': false,
      //     'error': 'User already has an active subscription',
      //     'errorCode': 'SUBSCRIPTION_EXISTS',
      //   };
      // }

      // Validate plan exists and amount matches
      final planValidation = await _validateSubscriptionPlan(planId, amount);
      if (!planValidation['valid']) {
        return {
          'success': false,
          'error': planValidation['error'],
          'errorCode': 'INVALID_PLAN',
        };
      }

      AppLogger.log('Subscription purchase validated successfully');

      return {
        'success': true,
        'subscriptionId': subscriptionId,
        'validatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      AppLogger.error('Error validating subscription purchase: $e');
      return {
        'success': false,
        'error': 'Subscription validation failed',
        'errorCode': 'VALIDATION_ERROR',
      };
    }
  }

  /// Check if currency is supported
  static bool _isValidCurrency(String currency) {
    const supportedCurrencies = ['USD', 'EUR', 'GBP', 'CAD', 'AUD'];
    return supportedCurrencies.contains(currency.toUpperCase());
  }

  /// Check for duplicate transactions
  static Future<bool> _checkDuplicateTransaction(
    String transactionId,
    String userId,
  ) async {
    try {
      final query =
          await FirebaseFirestore.instance
              .collection('payment_validations')
              .where('transactionId', isEqualTo: transactionId)
              .where('userId', isEqualTo: userId)
              .limit(1)
              .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      AppLogger.error('Error checking duplicate transaction: $e');
      return false;
    }
  }

  /// Store payment validation record
  static Future<void> _storePaymentValidation(Map<String, dynamic> data) async {
    try {
      // Generate document ID without calling Firestore
      final documentId =
          DateTime.now().millisecondsSinceEpoch.toString() +
          '_' +
          (data['userId'] ?? 'unknown').toString().substring(0, 8);

      await _batchService.addWrite(
        collection: 'payment_validations',
        documentId: documentId,
        data: data,
      );
      await _batchService.flushBatch();
    } catch (e) {
      AppLogger.error('Error storing payment validation: $e');
      rethrow;
    }
  }

  /// Check if user has active subscription
  static Future<bool> _checkActiveSubscription(String userId) async {
    try {
      final queryOptimizer = FirebaseQueryOptimizer();
      return await queryOptimizer.checkActiveSubscription(userId);
    } catch (e) {
      AppLogger.error('Error checking active subscription: $e');
      return false;
    }
  }

  /// Validate subscription plan
  static Future<Map<String, dynamic>> _validateSubscriptionPlan(
    String planId,
    double amount,
  ) async {
    try {
      // Validate against the plan configuration
      // The planId passed is the key ('super_payments'), but we need to check the actual plan data
      if (planId == 'super_payments' && amount == 1.99) {
        return {'valid': true};
      }

      return {'valid': false, 'error': 'Invalid plan or amount'};
    } catch (e) {
      return {'valid': false, 'error': 'Plan validation failed'};
    }
  }

  /// Generate unique session ID
  static String _generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  /// Get remaining session time in minutes
  static int getRemainingSessionTime() {
    if (!_isPaymentSessionActive || _lastActivity == null) {
      return 0;
    }

    final now = DateTime.now();
    final elapsed = now.difference(_lastActivity!).inMinutes;
    final remaining = _sessionTimeoutMinutes - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// Check if payment session is active
  static bool get isPaymentSessionActive => _isPaymentSessionActive;
}
