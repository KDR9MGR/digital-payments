import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../lib/utils/custom_color.dart';
import 'mock_custom_style.dart';

/// Mock user feedback service for testing without ScreenUtil dependencies
class MockUserFeedbackService {
  static final MockUserFeedbackService _instance = MockUserFeedbackService._internal();
  factory MockUserFeedbackService() => _instance;
  MockUserFeedbackService._internal();
  
  // Loading state management
  bool _isLoading = false;
  String _loadingMessage = 'Please wait...';
  
  bool get isLoading => _isLoading;
  String get loadingMessage => _loadingMessage;

  /// Show loading overlay with custom message
  void showLoading({
    String message = 'Please wait...',
    bool canDismiss = false,
  }) {
    if (_isLoading) return; // Prevent multiple loading dialogs
    
    _isLoading = true;
    _loadingMessage = message;
    
    // Mock loading dialog - just log for testing
    print('Loading: $message (canDismiss: $canDismiss)');
  }

  /// Show loading with progress indicator
  void showProgressLoading({
    required String message,
    required double progress,
    bool canDismiss = false,
  }) {
    if (_isLoading) {
      // Update existing loading dialog
      _updateProgressLoading(message: message, progress: progress);
      return;
    }
    
    _isLoading = true;
    _loadingMessage = message;
    
    // Mock progress loading dialog - just log for testing
    print('Progress Loading: $message (${(progress * 100).toInt()}%)');
  }

  /// Update progress loading dialog
  void _updateProgressLoading({
    required String message,
    required double progress,
  }) {
    _loadingMessage = message;
    // Note: In a real implementation, you'd need to use a stateful approach
    // to update the dialog content. This is a simplified version.
  }

  /// Hide loading overlay
  void hideLoading() {
    if (!_isLoading) return;
    
    _isLoading = false;
    _loadingMessage = 'Please wait...';
    
    // Mock hide loading - just log for testing
    print('Loading hidden');
  }

  /// Execute async operation with loading feedback
  Future<T?> executeWithLoading<T>({
    required Future<T> Function() operation,
    String loadingMessage = 'Processing...',
    String? successMessage,
    String? errorMessage,
    bool showSuccessSnackbar = true,
    bool showErrorDialog = false,
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) async {
    try {
      showLoading(message: loadingMessage);
      
      final result = await operation();
      
      hideLoading();
      
      if (successMessage != null && showSuccessSnackbar) {
        // Mock success feedback - just log for testing
        print('Success: $successMessage');
      }
      
      onSuccess?.call();
      return result;
    } catch (error) {
      hideLoading();
      
      if (showErrorDialog) {
        // Mock error dialog - just log for testing
        print('Error Dialog: ${errorMessage ?? error.toString()}');
      } else {
        // Mock error snackbar - just log for testing
        print('Error: ${errorMessage ?? error.toString()}');
      }
      
      onError?.call();
      rethrow;
    }
  }

  /// Show success message
  void showSuccess({
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Mock success message - just log for testing
    print('Success: $message');
  }

  /// Show error message
  void showError({
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Mock error message - just log for testing
    print('Error: $message');
  }

  /// Show info message
  void showInfo({
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Mock info message - just log for testing
    print('Info: $message');
  }

  /// Show confirmation dialog
  Future<bool> showConfirmationDialog({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) async {
    // Mock confirmation dialog - return true for testing
    print('Confirmation Dialog: $title - $message');
    return true;
  }

  /// Reset service state
  void reset() {
    _isLoading = false;
    _loadingMessage = 'Please wait...';
  }
}