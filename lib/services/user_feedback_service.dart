import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xpay/utils/custom_color.dart';
import 'package:xpay/utils/custom_style.dart';
import 'package:xpay/services/error_handling_service.dart';

/// Comprehensive user feedback service for loading states, progress, and notifications
class UserFeedbackService {
  static final UserFeedbackService _instance = UserFeedbackService._internal();
  factory UserFeedbackService() => _instance;
  UserFeedbackService._internal();

  final ErrorHandlingService _errorHandler = ErrorHandlingService();
  
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
    
    Get.dialog(
      WillPopScope(
        onWillPop: () async => canDismiss,
        child: AlertDialog(
          backgroundColor: CustomColor.surfaceColor,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(CustomColor.primaryColor),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: CustomStyle.commonTextTitleWhite,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: canDismiss,
    );
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
    
    Get.dialog(
      WillPopScope(
        onWillPop: () async => canDismiss,
        child: AlertDialog(
          backgroundColor: CustomColor.surfaceColor,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(CustomColor.primaryColor),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: CustomStyle.commonTextTitleWhite,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).toInt()}%',
                style: CustomStyle.commonTextTitleWhite.copyWith(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: canDismiss,
    );
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
    
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
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
        _errorHandler.showSuccess(message: successMessage);
      }
      
      onSuccess?.call();
      return result;
      
    } catch (error) {
      hideLoading();
      
      final displayMessage = errorMessage ?? 'Operation failed: ${error.toString()}';
      
      if (showErrorDialog) {
        await _errorHandler.handleError(
          errorType: ErrorHandlingService.unknownError,
          errorMessage: error.toString(),
          userFriendlyMessage: displayMessage,
          showDialog: true,
        );
      } else {
        await _errorHandler.handleError(
          errorType: ErrorHandlingService.unknownError,
          errorMessage: error.toString(),
          userFriendlyMessage: displayMessage,
          showDialog: false,
        );
      }
      
      onError?.call();
      return null;
    }
  }

  /// Execute async operation with progress feedback
  Future<T?> executeWithProgress<T>({
    required Future<T> Function(Function(double, String) updateProgress) operation,
    String initialMessage = 'Starting...',
    String? successMessage,
    String? errorMessage,
    bool showSuccessSnackbar = true,
    bool showErrorDialog = false,
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) async {
    try {
      showProgressLoading(message: initialMessage, progress: 0.0);
      
      final result = await operation((progress, message) {
        showProgressLoading(message: message, progress: progress);
      });
      
      hideLoading();
      
      if (successMessage != null && showSuccessSnackbar) {
        _errorHandler.showSuccess(message: successMessage);
      }
      
      onSuccess?.call();
      return result;
      
    } catch (error) {
      hideLoading();
      
      final displayMessage = errorMessage ?? 'Operation failed: ${error.toString()}';
      
      if (showErrorDialog) {
        await _errorHandler.handleError(
          errorType: ErrorHandlingService.unknownError,
          errorMessage: error.toString(),
          userFriendlyMessage: displayMessage,
          showDialog: true,
        );
      } else {
        await _errorHandler.handleError(
          errorType: ErrorHandlingService.unknownError,
          errorMessage: error.toString(),
          userFriendlyMessage: displayMessage,
          showDialog: false,
        );
      }
      
      onError?.call();
      return null;
    }
  }

  /// Show bottom sheet with custom content
  Future<T?> showBottomSheet<T>({
    required Widget content,
    String? title,
    bool isDismissible = true,
    bool enableDrag = true,
    double? height,
  }) async {
    return await Get.bottomSheet<T>(
      Container(
        height: height,
        decoration: const BoxDecoration(
          color: CustomColor.surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[700]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: CustomStyle.commonTextTitleWhite.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Flexible(child: content),
          ],
        ),
      ),
      isDismissible: isDismissible,
      enableDrag: enableDrag,
    );
  }

  /// Show action sheet with multiple options
  Future<T?> showActionSheet<T>({
    required String title,
    required List<ActionSheetOption<T>> options,
    bool showCancel = true,
    String cancelText = 'Cancel',
  }) async {
    return await showBottomSheet<T>(
      title: title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...options.map((option) => ListTile(
            leading: option.icon != null
                ? Icon(option.icon, color: option.isDestructive ? Colors.red : Colors.white)
                : null,
            title: Text(
              option.title,
              style: CustomStyle.commonTextTitleWhite.copyWith(
                color: option.isDestructive ? Colors.red : Colors.white,
              ),
            ),
            subtitle: option.subtitle != null
                ? Text(
                    option.subtitle!,
                    style: CustomStyle.commonTextTitleWhite.copyWith(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  )
                : null,
            onTap: () {
              Get.back(result: option.value);
            },
          )),
          if (showCancel) ...[
            const Divider(color: Colors.grey),
            ListTile(
              title: Text(
                cancelText,
                style: CustomStyle.commonTextTitleWhite.copyWith(
                  color: Colors.grey[400],
                ),
                textAlign: TextAlign.center,
              ),
              onTap: () => Get.back(),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Show confirmation dialog
  Future<bool> showConfirmation({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: CustomColor.surfaceColor,
        title: Text(
          title,
          style: CustomStyle.commonTextTitleWhite.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: CustomStyle.commonTextTitleWhite.copyWith(
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              cancelText,
              style: TextStyle(
                color: Colors.grey[400],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(
              confirmText,
              style: TextStyle(
                color: isDestructive ? Colors.red : CustomColor.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  /// Show toast message (short duration)
  void showToast({
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 2),
  }) {
    Color backgroundColor;
    IconData icon;
    
    switch (type) {
      case ToastType.success:
        backgroundColor = Colors.green[600]!;
        icon = Icons.check_circle;
        break;
      case ToastType.error:
        backgroundColor = Colors.red[600]!;
        icon = Icons.error;
        break;
      case ToastType.warning:
        backgroundColor = Colors.orange[600]!;
        icon = Icons.warning;
        break;
      case ToastType.info:
      default:
        backgroundColor = CustomColor.primaryColor;
        icon = Icons.info;
        break;
    }
    
    Get.rawSnackbar(
      message: message,
      backgroundColor: backgroundColor,
      icon: Icon(icon, color: Colors.white),
      duration: duration,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      isDismissible: true,
    );
  }

  /// Show persistent notification banner
  void showBanner({
    required String message,
    BannerType type = BannerType.info,
    VoidCallback? onAction,
    String? actionText,
    VoidCallback? onDismiss,
  }) {
    Color backgroundColor;
    IconData icon;
    
    switch (type) {
      case BannerType.success:
        backgroundColor = Colors.green[600]!;
        icon = Icons.check_circle;
        break;
      case BannerType.error:
        backgroundColor = Colors.red[600]!;
        icon = Icons.error;
        break;
      case BannerType.warning:
        backgroundColor = Colors.orange[600]!;
        icon = Icons.warning;
        break;
      case BannerType.info:
      default:
        backgroundColor = CustomColor.primaryColor;
        icon = Icons.info;
        break;
    }
    
    Get.showSnackbar(
      GetSnackBar(
        message: message,
        backgroundColor: backgroundColor,
        icon: Icon(icon, color: Colors.white),
        duration: const Duration(seconds: 5),
        snackPosition: SnackPosition.TOP,
        isDismissible: true,
        dismissDirection: DismissDirection.horizontal,
        mainButton: onAction != null && actionText != null
            ? TextButton(
                onPressed: () {
                  Get.closeCurrentSnackbar();
                  onAction();
                },
                child: Text(
                  actionText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: onDismiss != null
            ? (_) {
                Get.closeCurrentSnackbar();
                onDismiss();
              }
            : null,
      ),
    );
  }

  /// Dispose service
  void dispose() {
    hideLoading();
  }
}

/// Action sheet option model
class ActionSheetOption<T> {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final T value;
  final bool isDestructive;
  
  const ActionSheetOption({
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.isDestructive = false,
  });
}

/// Toast message types
enum ToastType {
  success,
  error,
  warning,
  info,
}

/// Banner message types
enum BannerType {
  success,
  error,
  warning,
  info,
}