import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../utils/app_logger.dart';
import 'subscription_service.dart';

/// Service for handling subscription-related notifications
class NotificationService extends GetxService {
  static NotificationService get instance => Get.find<NotificationService>();
  
  final GetStorage _storage = GetStorage();
  
  // Storage keys
  static const String _lastExpiryWarningKey = 'last_expiry_warning';
  static const String _notificationPreferencesKey = 'notification_preferences';
  
  // Notification preferences
  bool _renewalNotificationsEnabled = true;
  bool _expiryWarningsEnabled = true;
  bool _gracePeriodNotificationsEnabled = true;
  
  // Timers for scheduled notifications
  Timer? _renewalReminderTimer;
  Timer? _expiryWarningTimer;
  
  @override
  Future<void> onInit() async {
    super.onInit();
    await _loadNotificationPreferences();
    _schedulePeriodicChecks();
    AppLogger.log('Notification service initialized successfully');
  }
  
  @override
  void onClose() {
    _renewalReminderTimer?.cancel();
    _expiryWarningTimer?.cancel();
    super.onClose();
  }
  
  /// Load notification preferences
  Future<void> _loadNotificationPreferences() async {
    final prefs = _storage.read(_notificationPreferencesKey) ?? {};
    _renewalNotificationsEnabled = prefs['renewal'] ?? true;
    _expiryWarningsEnabled = prefs['expiry'] ?? true;
    _gracePeriodNotificationsEnabled = prefs['gracePeriod'] ?? true;
  }
  
  /// Save notification preferences
  Future<void> _saveNotificationPreferences() async {
    await _storage.write(_notificationPreferencesKey, {
      'renewal': _renewalNotificationsEnabled,
      'expiry': _expiryWarningsEnabled,
      'gracePeriod': _gracePeriodNotificationsEnabled,
    });
  }
  
  /// Schedule periodic notification checks
  void _schedulePeriodicChecks() {
    // Check for renewal reminders every 6 hours
    _renewalReminderTimer = Timer.periodic(
      const Duration(hours: 6),
      (_) => _checkRenewalReminders(),
    );
    
    // Check for expiry warnings every 2 hours
    _expiryWarningTimer = Timer.periodic(
      const Duration(hours: 2),
      (_) => _checkExpiryWarnings(),
    );
  }
  
  /// Check and send renewal reminders
  Future<void> _checkRenewalReminders() async {
    if (!_renewalNotificationsEnabled) return;
    
    try {
      final subscriptionService = Get.find<SubscriptionService>();
      
      // Check if subscription is expiring soon
       if (subscriptionService.hasActiveSubscriptionWithoutGrace) {
         // For active subscriptions, we can check if grace period is about to start
         // This would indicate subscription is about to expire
         // Since we don't have direct access to expiry date, we'll rely on the service's internal checks
       }
      
    } catch (e) {
      AppLogger.log('Error checking renewal reminders: $e');
    }
  }
  
  /// Check and send expiry warnings
  Future<void> _checkExpiryWarnings() async {
    if (!_expiryWarningsEnabled) return;
    
    try {
      final subscriptionService = Get.find<SubscriptionService>();
      
      // Check if subscription has expired
      if (!subscriptionService.hasActiveSubscription && 
          subscriptionService.isInGracePeriod) {
        await _sendGracePeriodWarning();
      }
      
      // Check if grace period is ending soon
      if (subscriptionService.isInGracePeriod) {
        final gracePeriodEnd = subscriptionService.gracePeriodEnd;
        
        if (gracePeriodEnd != null) {
          final hoursUntilGracePeriodEnd = gracePeriodEnd.difference(DateTime.now()).inHours;
          
          if (hoursUntilGracePeriodEnd <= 24 && hoursUntilGracePeriodEnd > 0) {
            await _sendGracePeriodExpiryWarning(hoursUntilGracePeriodEnd);
          }
        }
      }
      
    } catch (e) {
      AppLogger.log('Error checking expiry warnings: $e');
    }
  }
  

  
  /// Send grace period warning
  Future<void> _sendGracePeriodWarning() async {
    if (!_gracePeriodNotificationsEnabled) return;
    
    final lastWarning = _storage.read(_lastExpiryWarningKey);
    final today = DateTime.now().day;
    
    // Don't send multiple warnings in one day
    if (lastWarning == today) return;
    
    Get.snackbar(
      'Subscription Expired - Grace Period Active',
      'Your subscription has expired but you still have access during the grace period. Renew now to avoid losing premium features.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Get.theme.colorScheme.tertiary,
      colorText: Get.theme.colorScheme.onPrimary,
      duration: const Duration(seconds: 6),
      mainButton: TextButton(
        onPressed: () {
          Get.back();
          Get.toNamed('/subscription');
        },
        child: Text(
          'Renew Now',
          style: TextStyle(color: Get.theme.colorScheme.onPrimary),
        ),
      ),
    );
    
    _storage.write(_lastExpiryWarningKey, today);
    AppLogger.log('Sent grace period warning');
  }
  
  /// Send grace period expiry warning
  Future<void> _sendGracePeriodExpiryWarning(int hoursLeft) async {
    // Show urgent in-app notification
    Get.snackbar(
      'Urgent: Grace Period Ending',
      'Only $hoursLeft hours left in your grace period! Renew now to maintain access.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Get.theme.colorScheme.error,
      colorText: Get.theme.colorScheme.onError,
      duration: const Duration(seconds: 8),
      isDismissible: false,
      mainButton: TextButton(
        onPressed: () {
          Get.back();
          Get.toNamed('/subscription');
        },
        child: Text(
          'Renew Now',
          style: TextStyle(color: Get.theme.colorScheme.onError),
        ),
      ),
    );
    
    AppLogger.log('Sent grace period expiry warning for $hoursLeft hours');
  }
  
  /// Send payment failure notification
  Future<void> sendPaymentFailureNotification() async {
    Get.snackbar(
      'Payment Failed',
      'Your subscription renewal payment failed. Please update your payment method.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Get.theme.colorScheme.error,
      colorText: Get.theme.colorScheme.onError,
      duration: const Duration(seconds: 6),
      mainButton: TextButton(
        onPressed: () {
          Get.back();
          Get.toNamed('/subscription');
        },
        child: Text(
          'Update Payment',
          style: TextStyle(color: Get.theme.colorScheme.onError),
        ),
      ),
    );
    
    AppLogger.log('Sent payment failure notification');
  }
  
  /// Send successful renewal notification
  Future<void> sendRenewalSuccessNotification() async {
    Get.snackbar(
      'Subscription Renewed',
      'Your premium subscription has been successfully renewed. Thank you!',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Get.theme.colorScheme.primary,
      colorText: Get.theme.colorScheme.onPrimary,
      duration: const Duration(seconds: 3),
    );
    
    AppLogger.log('Sent renewal success notification');
  }
  
  /// Send subscription expired notification
  Future<void> sendSubscriptionExpiredNotification() async {
    Get.snackbar(
      'Subscription Expired',
      'Your premium subscription has expired. Renew now to restore access to premium features.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Get.theme.colorScheme.error,
      colorText: Get.theme.colorScheme.onError,
      duration: const Duration(seconds: 8),
      isDismissible: false,
      mainButton: TextButton(
        onPressed: () {
          Get.back();
          Get.toNamed('/subscription');
        },
        child: Text(
          'Renew',
          style: TextStyle(color: Get.theme.colorScheme.onError),
        ),
      ),
    );
    
    AppLogger.log('Sent subscription expired notification');
  }
  
  /// Show subscription status dialog
  Future<void> showSubscriptionStatusDialog() async {
    final subscriptionService = Get.find<SubscriptionService>();
    
    String title;
    String content;
    Color backgroundColor;
    
    if (subscriptionService.hasActiveSubscription) {
      title = 'Active Subscription';
      content = 'Your premium subscription is active and will renew automatically.';
      backgroundColor = Get.theme.colorScheme.primary;
    } else if (subscriptionService.isInGracePeriod) {
      title = 'Grace Period Active';
      content = 'Your subscription has expired but you still have access during the grace period. Renew now to avoid losing premium features.';
      backgroundColor = Get.theme.colorScheme.tertiary;
    } else {
      title = 'Subscription Required';
      content = 'You need an active subscription to access premium features. Subscribe now to unlock all features.';
      backgroundColor = Get.theme.colorScheme.error;
    }
    
    Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Text(content),
        backgroundColor: backgroundColor.withValues(alpha: 0.1),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.toNamed('/subscription');
            },
            child: Text(subscriptionService.hasActiveSubscription ? 'Manage' : 'Subscribe'),
          ),
        ],
      ),
    );
  }
  
  /// Update notification preferences
  Future<void> updateNotificationPreferences({
    bool? renewalNotifications,
    bool? expiryWarnings,
    bool? gracePeriodNotifications,
  }) async {
    if (renewalNotifications != null) {
      _renewalNotificationsEnabled = renewalNotifications;
    }
    if (expiryWarnings != null) {
      _expiryWarningsEnabled = expiryWarnings;
    }
    if (gracePeriodNotifications != null) {
      _gracePeriodNotificationsEnabled = gracePeriodNotifications;
    }
    
    await _saveNotificationPreferences();
    AppLogger.log('Updated notification preferences');
  }
  
  /// Get notification preferences
  Map<String, bool> get notificationPreferences => {
    'renewal': _renewalNotificationsEnabled,
    'expiry': _expiryWarningsEnabled,
    'gracePeriod': _gracePeriodNotificationsEnabled,
  };
  
  /// Manually trigger subscription status check
  Future<void> checkSubscriptionStatus() async {
    await _checkRenewalReminders();
    await _checkExpiryWarnings();
  }
}