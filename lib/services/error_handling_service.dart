import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xpay/utils/custom_color.dart';
import 'package:xpay/utils/custom_style.dart';
import 'package:xpay/utils/app_logger.dart';

/// Comprehensive error handling service for the application
class ErrorHandlingService {
  static final ErrorHandlingService _instance = ErrorHandlingService._internal();
  factory ErrorHandlingService() => _instance;
  ErrorHandlingService._internal();

  // Error types
  static const String networkError = 'network_error';
  static const String authError = 'auth_error';
  static const String paymentError = 'payment_error';
  static const String validationError = 'validation_error';
  static const String serverError = 'server_error';
  static const String unknownError = 'unknown_error';

  /// Handle different types of errors with appropriate user feedback
  Future<void> handleError({
    required String errorType,
    required String errorMessage,
    String? userFriendlyMessage,
    VoidCallback? onRetry,
    VoidCallback? onAction,
    String? actionText,
    bool showDialog = false,
    bool logError = true,
  }) async {
    if (logError) {
      AppLogger.log('ERROR [$errorType]: $errorMessage');
    }

    final String displayMessage = userFriendlyMessage ?? _getDefaultMessage(errorType, errorMessage);
    final String title = _getErrorTitle(errorType);
    final IconData icon = _getErrorIcon(errorType);
    final Color color = _getErrorColor(errorType);

    if (showDialog) {
      _showErrorDialog(
        title: title,
        message: displayMessage,
        icon: icon,
        color: color,
        onRetry: onRetry,
        onAction: onAction,
        actionText: actionText,
      );
    } else {
      _showErrorSnackbar(
        title: title,
        message: displayMessage,
        icon: icon,
        color: color,
        onAction: onAction,
        actionText: actionText,
      );
    }
  }

  /// Show success feedback
  void showSuccess({
    required String message,
    String title = 'Success',
    VoidCallback? onAction,
    String? actionText,
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.green[600],
      colorText: Colors.white,
      icon: const Icon(Icons.check_circle, color: Colors.white),
      duration: const Duration(seconds: 3),
      isDismissible: true,
      mainButton: onAction != null && actionText != null
          ? TextButton(
              onPressed: onAction,
              child: Text(
                actionText,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  /// Show warning feedback
  void showWarning({
    required String message,
    String title = 'Warning',
    VoidCallback? onAction,
    String? actionText,
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange[600],
      colorText: Colors.white,
      icon: const Icon(Icons.warning, color: Colors.white),
      duration: const Duration(seconds: 4),
      isDismissible: true,
      mainButton: onAction != null && actionText != null
          ? TextButton(
              onPressed: onAction,
              child: Text(
                actionText,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  /// Show info feedback
  void showInfo({
    required String message,
    String title = 'Info',
    VoidCallback? onAction,
    String? actionText,
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: CustomColor.primaryColor,
      colorText: Colors.white,
      icon: const Icon(Icons.info, color: Colors.white),
      duration: const Duration(seconds: 3),
      isDismissible: true,
      mainButton: onAction != null && actionText != null
          ? TextButton(
              onPressed: onAction,
              child: Text(
                actionText,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  /// Handle network errors specifically
  Future<void> handleNetworkError({
    String? customMessage,
    VoidCallback? onRetry,
    bool showDialog = false,
  }) async {
    await handleError(
      errorType: networkError,
      errorMessage: 'Network connection failed',
      userFriendlyMessage: customMessage ?? 'Please check your internet connection and try again.',
      onRetry: onRetry,
      actionText: onRetry != null ? 'Retry' : null,
      showDialog: showDialog,
    );
  }

  /// Handle authentication errors specifically
  Future<void> handleAuthError({
    required String errorCode,
    String? customMessage,
    VoidCallback? onAction,
    bool showDialog = true,
  }) async {
    String message = customMessage ?? _getAuthErrorMessage(errorCode);
    
    await handleError(
      errorType: authError,
      errorMessage: 'Auth error: $errorCode',
      userFriendlyMessage: message,
      onAction: onAction,
      actionText: onAction != null ? 'Try Again' : null,
      showDialog: showDialog,
    );
  }

  /// Handle payment errors specifically
  Future<void> handlePaymentError({
    required String errorCode,
    String? customMessage,
    VoidCallback? onRetry,
    VoidCallback? onUpdatePayment,
    bool showDialog = true,
  }) async {
    String message = customMessage ?? _getPaymentErrorMessage(errorCode);
    VoidCallback? action = onUpdatePayment ?? onRetry;
    String? actionText;
    
    if (onUpdatePayment != null) {
      actionText = 'Update Payment';
    } else if (onRetry != null) {
      actionText = 'Retry';
    }
    
    await handleError(
      errorType: paymentError,
      errorMessage: 'Payment error: $errorCode',
      userFriendlyMessage: message,
      onAction: action,
      actionText: actionText,
      showDialog: showDialog,
    );
  }

  /// Handle validation errors specifically
  Future<void> handleValidationError({
    required String field,
    required String message,
    bool showDialog = false,
  }) async {
    await handleError(
      errorType: validationError,
      errorMessage: 'Validation error in $field: $message',
      userFriendlyMessage: message,
      showDialog: showDialog,
    );
  }

  // Private helper methods
  String _getDefaultMessage(String errorType, String errorMessage) {
    switch (errorType) {
      case networkError:
        return 'Please check your internet connection and try again.';
      case authError:
        return 'Authentication failed. Please try again.';
      case paymentError:
        return 'Payment processing failed. Please try again.';
      case validationError:
        return 'Please check your input and try again.';
      case serverError:
        return 'Server error occurred. Please try again later.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  String _getErrorTitle(String errorType) {
    switch (errorType) {
      case networkError:
        return 'Connection Error';
      case authError:
        return 'Authentication Error';
      case paymentError:
        return 'Payment Error';
      case validationError:
        return 'Invalid Input';
      case serverError:
        return 'Server Error';
      default:
        return 'Error';
    }
  }

  IconData _getErrorIcon(String errorType) {
    switch (errorType) {
      case networkError:
        return Icons.wifi_off;
      case authError:
        return Icons.lock;
      case paymentError:
        return Icons.payment;
      case validationError:
        return Icons.error_outline;
      case serverError:
        return Icons.cloud_off;
      default:
        return Icons.error;
    }
  }

  Color _getErrorColor(String errorType) {
    switch (errorType) {
      case networkError:
        return Colors.orange[600]!;
      case authError:
        return Colors.red[600]!;
      case paymentError:
        return Colors.red[700]!;
      case validationError:
        return Colors.amber[600]!;
      case serverError:
        return Colors.red[800]!;
      default:
        return Colors.red[600]!;
    }
  }

  String _getAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  String _getPaymentErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'insufficient-funds':
        return 'Insufficient funds. Please add money to your account or use a different payment method.';
      case 'card-declined':
        return 'Your card was declined. Please contact your bank or try a different card.';
      case 'expired-card':
        return 'Your card has expired. Please update your payment method.';
      case 'invalid-card':
        return 'Invalid card information. Please check your details and try again.';
      case 'payment-cancelled':
        return 'Payment was cancelled.';
      case 'processing-error':
        return 'Payment processing failed. Please try again.';
      case 'network-error':
        return 'Network error during payment. Please check your connection and try again.';
      default:
        return 'Payment failed. Please try again.';
    }
  }

  void _showErrorSnackbar({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    VoidCallback? onAction,
    String? actionText,
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: color,
      colorText: Colors.white,
      icon: Icon(icon, color: Colors.white),
      duration: const Duration(seconds: 4),
      isDismissible: true,
      mainButton: onAction != null && actionText != null
          ? TextButton(
              onPressed: onAction,
              child: Text(
                actionText,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  void _showErrorDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    VoidCallback? onRetry,
    VoidCallback? onAction,
    String? actionText,
  }) {
    Get.dialog(
      AlertDialog(
        backgroundColor: CustomColor.surfaceColor,
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: CustomStyle.commonTextTitleWhite,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: CustomStyle.commonTextTitleWhite.copyWith(fontSize: 14),
        ),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Get.back();
                onRetry();
              },
              child: Text(
                'Retry',
                style: TextStyle(color: CustomColor.primaryColor),
              ),
            ),
          if (onAction != null && actionText != null)
            TextButton(
              onPressed: () {
                Get.back();
                onAction();
              },
              child: Text(
                actionText,
                style: TextStyle(color: CustomColor.primaryColor),
              ),
            ),
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'OK',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Show loading dialog
  void showLoading({String message = 'Please wait...'}) {
    Get.dialog(
      AlertDialog(
        backgroundColor: CustomColor.surfaceColor,
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: CustomStyle.commonTextTitleWhite,
              ),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }

  /// Hide loading dialog
  void hideLoading() {
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
  }

  /// Show confirmation dialog
  Future<bool> showConfirmation({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    bool? result = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: CustomColor.surfaceColor,
        title: Text(
          title,
          style: CustomStyle.commonTextTitleWhite,
        ),
        content: Text(
          message,
          style: CustomStyle.commonTextTitleWhite.copyWith(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              cancelText,
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(
              confirmText,
              style: TextStyle(
                color: isDestructive ? Colors.red[400] : CustomColor.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
    
    return result ?? false;
  }
}