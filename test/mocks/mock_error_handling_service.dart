import 'package:flutter/material.dart';
import 'package:xpay/utils/app_logger.dart';

/// Mock ErrorHandlingService for testing without ScreenUtil dependencies
class MockErrorHandlingService {
  static final MockErrorHandlingService _instance = MockErrorHandlingService._internal();
  factory MockErrorHandlingService() => _instance;
  MockErrorHandlingService._internal();

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
      // Mock dialog - just log for testing
      print('Error Dialog: $title - $displayMessage');
      if (onRetry != null) {
        print('Retry callback available');
      }
      if (onAction != null) {
        print('Action callback available: $actionText');
      }
    } else {
      // Mock snackbar - just log for testing
      print('Error Snackbar: $displayMessage');
    }
  }

  /// Show error snackbar
  void showErrorSnackbar({
    required String message,
    String? actionText,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Mock snackbar - just log for testing
    print('Error Snackbar: $message');
    if (onAction != null) {
      print('Action available: $actionText');
    }
  }

  /// Show success snackbar
  void showSuccessSnackbar({
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Mock success snackbar - just log for testing
    print('Success Snackbar: $message');
  }

  /// Show info snackbar
  void showInfoSnackbar({
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Mock info snackbar - just log for testing
    print('Info Snackbar: $message');
  }

  /// Show warning snackbar
  void showWarningSnackbar({
    required String message,
    String? actionText,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Mock warning snackbar - just log for testing
    print('Warning Snackbar: $message');
    if (onAction != null) {
      print('Action available: $actionText');
    }
  }

  /// Handle network errors specifically
  Future<void> handleNetworkError({
    required String errorMessage,
    VoidCallback? onRetry,
    bool showDialog = false,
  }) async {
    await handleError(
      errorType: networkError,
      errorMessage: errorMessage,
      onRetry: onRetry,
      showDialog: showDialog,
    );
  }

  /// Handle authentication errors specifically
  Future<void> handleAuthError({
    required String errorMessage,
    VoidCallback? onAction,
    String? actionText,
    bool showDialog = true,
  }) async {
    await handleError(
      errorType: authError,
      errorMessage: errorMessage,
      onAction: onAction,
      actionText: actionText ?? 'Login Again',
      showDialog: showDialog,
    );
  }

  /// Handle payment errors specifically
  Future<void> handlePaymentError({
    required String errorMessage,
    VoidCallback? onRetry,
    bool showDialog = true,
  }) async {
    await handleError(
      errorType: paymentError,
      errorMessage: errorMessage,
      onRetry: onRetry,
      showDialog: showDialog,
    );
  }

  /// Handle validation errors specifically
  Future<void> handleValidationError({
    required String errorMessage,
    bool showDialog = false,
  }) async {
    await handleError(
      errorType: validationError,
      errorMessage: errorMessage,
      showDialog: showDialog,
    );
  }

  /// Handle server errors specifically
  Future<void> handleServerError({
    required String errorMessage,
    VoidCallback? onRetry,
    bool showDialog = true,
  }) async {
    await handleError(
      errorType: serverError,
      errorMessage: errorMessage,
      onRetry: onRetry,
      showDialog: showDialog,
    );
  }

  /// Get default error message based on error type
  String _getDefaultMessage(String errorType, String originalMessage) {
    switch (errorType) {
      case networkError:
        return 'Network connection failed. Please check your internet connection and try again.';
      case authError:
        return 'Authentication failed. Please login again.';
      case paymentError:
        return 'Payment processing failed. Please try again or contact support.';
      case validationError:
        return originalMessage.isNotEmpty ? originalMessage : 'Invalid input. Please check your data.';
      case serverError:
        return 'Server error occurred. Please try again later.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Get error title based on error type
  String _getErrorTitle(String errorType) {
    switch (errorType) {
      case networkError:
        return 'Connection Error';
      case authError:
        return 'Authentication Error';
      case paymentError:
        return 'Payment Error';
      case validationError:
        return 'Validation Error';
      case serverError:
        return 'Server Error';
      default:
        return 'Error';
    }
  }

  /// Get error icon based on error type
  IconData _getErrorIcon(String errorType) {
    switch (errorType) {
      case networkError:
        return Icons.wifi_off;
      case authError:
        return Icons.lock;
      case paymentError:
        return Icons.payment;
      case validationError:
        return Icons.warning;
      case serverError:
        return Icons.error_outline;
      default:
        return Icons.error;
    }
  }

  /// Get error color based on error type
  Color _getErrorColor(String errorType) {
    switch (errorType) {
      case networkError:
        return Colors.orange;
      case authError:
        return Colors.red;
      case paymentError:
        return Colors.purple;
      case validationError:
        return Colors.amber;
      case serverError:
        return Colors.red;
      default:
        return Colors.red;
    }
  }
}