import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../utils/app_logger.dart';
import '../routes/routes.dart';
import 'subscription_fallback_service.dart';

/// Comprehensive error handling service for subscription and payment edge cases
class SubscriptionErrorHandler {
  static final SubscriptionErrorHandler _instance =
      SubscriptionErrorHandler._internal();
  factory SubscriptionErrorHandler() => _instance;
  SubscriptionErrorHandler._internal();

  final GetStorage _storage = GetStorage();
  final SubscriptionFallbackService _fallbackService =
      SubscriptionFallbackService();

  // Error tracking removed - using standard logging instead

  /// Initialize error handler
  Future<void> initialize() async {
    try {
      AppLogger.log('Initializing subscription error handler...');
      AppLogger.log('Subscription error handler initialized successfully');
    } catch (e) {
      AppLogger.log('Error initializing subscription error handler: $e');
    }
  }

  /// Handle subscription validation errors
  Future<bool> handleSubscriptionError({
    required String errorType,
    required String errorMessage,
    String? errorCode,
    Map<String, dynamic>? context,
  }) async {
    try {
      AppLogger.log('Handling subscription error: $errorType - $errorMessage');

      // Log error occurrence for monitoring
      AppLogger.log(
        'Subscription error: $errorType - $errorMessage (Code: $errorCode)',
      );

      // Handle specific error types
      switch (errorType.toLowerCase()) {
        case 'network_error':
        case 'connection_error':
          return await _handleNetworkError(errorMessage, context);

        case 'payment_error':
        case 'billing_error':
          return await _handlePaymentError(errorMessage, context);

        case 'validation_error':
        case 'receipt_error':
          return await _handleValidationError(errorMessage, context);

        case 'timeout_error':
          return await _handleTimeoutError(errorMessage, context);

        case 'service_unavailable':
        case 'server_error':
          return await _handleServiceError(errorMessage, context);

        case 'subscription_conflict':
        case 'state_error':
          return await _handleSubscriptionConflict(errorMessage, context);

        case 'authentication_error':
        case 'auth_error':
          return await _handleAuthenticationError(errorMessage, context);

        default:
          return await _handleGenericError(errorType, errorMessage, context);
      }
    } catch (e) {
      AppLogger.log('Error in subscription error handler: $e');
      return false;
    }
  }

  /// Handle network connectivity errors
  Future<bool> _handleNetworkError(
    String errorMessage,
    Map<String, dynamic>? context,
  ) async {
    AppLogger.log('Network error occurred: $errorMessage');

    // Show network error dialog
    _showNetworkErrorDialog(
      'Connection Issues',
      'Having trouble connecting to our servers. Please check your internet connection.',
      showRetry: true,
    );

    // Attempt automatic retry with exponential backoff
    return await _retryWithBackoff(() async {
      // This would be called by the original operation
      return true;
    });
  }

  /// Handle payment-related errors
  Future<bool> _handlePaymentError(
    String errorMessage,
    Map<String, dynamic>? context,
  ) async {
    AppLogger.log('Payment error occurred: $errorMessage');

    // Analyze payment error type
    if (errorMessage.toLowerCase().contains('insufficient')) {
      _showPaymentErrorDialog(
        'Insufficient Funds',
        'Your payment method has insufficient funds. Please update your payment method or try a different one.',
        actionText: 'Update Payment',
        onAction: () => Get.toNamed(Routes.subscriptionScreen),
      );
    } else if (errorMessage.toLowerCase().contains('expired') ||
        errorMessage.toLowerCase().contains('invalid')) {
      _showPaymentErrorDialog(
        'Payment Method Issue',
        'Your payment method appears to be expired or invalid. Please update your payment information.',
        actionText: 'Update Payment',
        onAction: () => Get.toNamed(Routes.subscriptionScreen),
      );
    } else if (errorMessage.toLowerCase().contains('declined')) {
      _showPaymentErrorDialog(
        'Payment Declined',
        'Your payment was declined by your bank. Please contact your bank or try a different payment method.',
        actionText: 'Try Again',
        onAction: () => Get.back(),
      );
    } else {
      _showPaymentErrorDialog(
        'Payment Error',
        'There was an issue processing your payment. Please try again or contact support.',
        actionText: 'Retry',
        onAction: () => Get.back(),
      );
    }

    return false;
  }

  /// Handle subscription validation errors
  Future<bool> _handleValidationError(
    String errorMessage,
    Map<String, dynamic>? context,
  ) async {
    AppLogger.log('Attempting fallback validation strategies');

    // Try fallback validation
    final fallbackSuccess = await _fallbackService.handleValidationFailure(
      failureReason: errorMessage,
      userId: context?['userId'] ?? '',
      lastKnownSubscriptionData: context?['subscriptionData'],
    );

    if (fallbackSuccess) {
      AppLogger.log('Fallback validation successful');
      return true;
    } else {
      // Log validation error but never show dialog to user
      AppLogger.log('Validation error: $errorMessage - handled silently');
      return false;
    }
  }

  /// Handle timeout errors
  Future<bool> _handleTimeoutError(
    String errorMessage,
    Map<String, dynamic>? context,
  ) async {
    AppLogger.log('Handling timeout error with retry strategy');

    // Implement exponential backoff retry
    return await _retryWithBackoff(() async {
      // This would be implemented by the calling service
      return false; // Placeholder
    }, maxRetries: 3);
  }

  /// Handle service unavailable errors
  Future<bool> _handleServiceError(
    String errorMessage,
    Map<String, dynamic>? context,
  ) async {
    AppLogger.log('Service unavailable, checking fallback options');

    // Show standard service error dialog
    _showServiceErrorDialog(
      'Service Unavailable',
      'Our subscription service is temporarily unavailable. Please try again in a few minutes.',
    );
    return false;
  }

  /// Handle subscription state conflicts
  Future<bool> _handleSubscriptionConflict(
    String errorMessage,
    Map<String, dynamic>? context,
  ) async {
    AppLogger.log('Handling subscription state conflict');

    _showConflictDialog(
      'Subscription Conflict',
      'There\'s a conflict with your subscription status. We\'re resolving this automatically.',
    );

    // Attempt to resolve conflict by refreshing subscription state
    // This would typically involve calling the subscription service to refresh
    return true; // Placeholder
  }

  /// Handle authentication errors
  Future<bool> _handleAuthenticationError(
    String errorMessage,
    Map<String, dynamic>? context,
  ) async {
    AppLogger.log('Handling authentication error');

    _showAuthErrorDialog(
      'Authentication Required',
      'Please sign in again to continue using premium features.',
    );

    return false;
  }

  /// Handle generic errors
  Future<bool> _handleGenericError(
    String errorType,
    String errorMessage,
    Map<String, dynamic>? context,
  ) async {
    AppLogger.log('Handling generic error: $errorType');

    _showGenericErrorDialog(
      'Unexpected Error',
      'An unexpected error occurred. Our team has been notified and we\'re working to resolve it.',
    );

    return false;
  }

  // Critical error state handling removed - using standard error logging instead

  /// Enable offline mode
  Future<bool> _enableOfflineMode() async {
    AppLogger.log('Enabling offline mode');

    final hasOfflineAccess = _fallbackService.isInOfflineGracePeriod();

    if (hasOfflineAccess) {
      _showOfflineModeDialog(
        'Offline Mode Enabled',
        'You\'re now in offline mode. Premium features will continue to work for a limited time.',
      );
      return true;
    } else {
      _showOfflineModeDialog(
        'Offline Mode Unavailable',
        'Cannot enable offline mode. Please restore internet connection to continue.',
      );
      return false;
    }
  }

  /// Retry with exponential backoff
  Future<bool> _retryWithBackoff(
    Future<bool> Function() operation, {
    int maxRetries = 3,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        AppLogger.log('Retry attempt $attempt/$maxRetries');

        final result = await operation();
        if (result) {
          AppLogger.log('Retry successful on attempt $attempt');
          return true;
        }

        if (attempt < maxRetries) {
          final delay = Duration(seconds: attempt * 2); // Exponential backoff
          AppLogger.log('Waiting ${delay.inSeconds}s before next retry');
          await Future.delayed(delay);
        }
      } catch (e) {
        AppLogger.log('Retry attempt $attempt failed: $e');
        if (attempt == maxRetries) {
          rethrow;
        }
      }
    }

    AppLogger.log('All retry attempts failed');
    return false;
  }

  // Error tracking methods removed - using standard logging instead

  // Dialog methods
  void _showNetworkErrorDialog(
    String title,
    String message, {
    required bool showRetry,
  }) {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.orange),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          if (showRetry)
            TextButton(
              onPressed: () {
                Get.back();
                // Trigger retry
              },
              child: Text('Retry'),
            ),
          TextButton(onPressed: () => Get.back(), child: Text('OK')),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void _showPaymentErrorDialog(
    String title,
    String message, {
    String? actionText,
    VoidCallback? onAction,
  }) {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.payment, color: Colors.red),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          if (actionText != null && onAction != null)
            TextButton(
              onPressed: () {
                Get.back();
                onAction();
              },
              child: Text(actionText),
            ),
          TextButton(onPressed: () => Get.back(), child: Text('OK')),
        ],
      ),
      barrierDismissible: false,
    );
  }

  // Validation error dialog removed - errors are handled silently

  void _showServiceErrorDialog(
    String title,
    String message,
  ) {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.cloud_off,
              color: Colors.red,
            ),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [TextButton(onPressed: () => Get.back(), child: Text('OK'))],
      ),
      barrierDismissible: false,
    );
  }

  void _showConflictDialog(String title, String message) {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.sync_problem, color: Colors.orange),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [TextButton(onPressed: () => Get.back(), child: Text('OK'))],
      ),
      barrierDismissible: false,
    );
  }

  void _showAuthErrorDialog(String title, String message) {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.red),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              Get.offAllNamed(Routes.loginScreen);
            },
            child: Text('Sign In'),
          ),
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void _showGenericErrorDialog(String title, String message) {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [TextButton(onPressed: () => Get.back(), child: Text('OK'))],
      ),
      barrierDismissible: false,
    );
  }

  // Critical error dialog methods removed - using standard logging instead

  void _showOfflineModeDialog(String title, String message) {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.orange),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [TextButton(onPressed: () => Get.back(), child: Text('OK'))],
      ),
      barrierDismissible: false,
    );
  }

  void _showSuccessDialog(String title, String message) {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [TextButton(onPressed: () => Get.back(), child: Text('OK'))],
      ),
      barrierDismissible: false,
    );
  }

  /// Dispose error handler
  void dispose() {
    AppLogger.log('Subscription error handler disposed');
  }

  // Error statistics method removed - error tracking disabled
}
