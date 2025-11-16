import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/apple_subscription_service.dart';
import '../services/google_subscription_service.dart';
import '../services/subscription_service.dart';
import '../config/subscription_config.dart';
import '../utils/app_logger.dart';

/// Unified subscription controller that manages both Apple and Google subscriptions
class UnifiedSubscriptionController extends GetxController {
  // Platform-specific services
  final AppleSubscriptionService _appleService = AppleSubscriptionService();
  final GoogleSubscriptionService _googleService = GoogleSubscriptionService();
  final SubscriptionService _mainService = SubscriptionService();

  // Reactive variables
  final RxBool isLoading = false.obs;
  final RxBool isSubscriptionActive = false.obs;
  final RxString currentPlatform = ''.obs;
  final RxString subscriptionStatus = 'inactive'.obs;
  final Rx<DateTime?> expiryDate = Rx<DateTime?>(null);
  final RxMap<String, dynamic> subscriptionDetails = <String, dynamic>{}.obs;

  // Stream subscription for purchase updates
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  @override
  void onInit() {
    super.onInit();
    _initializeServices();
    _listenToPurchaseUpdates();
  }

  @override
  void onClose() {
    _purchaseSubscription?.cancel();
    _appleService.dispose();
    _googleService.dispose();
    super.onClose();
  }

  /// Initialize platform-specific subscription services
  Future<void> _initializeServices() async {
    try {
      isLoading.value = true;
      AppLogger.log('Initializing unified subscription services...');

      // Initialize main subscription service
      await _mainService.initialize();

      // Initialize platform-specific services
      if (io.Platform.isIOS) {
        await _appleService.initialize();
        currentPlatform.value = 'ios';
        AppLogger.log('Apple subscription service initialized');
      } else if (io.Platform.isAndroid) {
        await _googleService.initialize();
        currentPlatform.value = 'android';
        AppLogger.log('Google subscription service initialized');
      }

      // Check current subscription status
      await refreshSubscriptionStatus();

      AppLogger.log('Unified subscription services initialized successfully');
    } catch (e) {
      AppLogger.log('Error initializing subscription services: $e');
      _showError('Failed to initialize subscription services');
    } finally {
      isLoading.value = false;
    }
  }

  /// Listen to purchase updates from the platform
  void _listenToPurchaseUpdates() {
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        InAppPurchase.instance.purchaseStream;
    _purchaseSubscription = purchaseUpdated.listen(
      (List<PurchaseDetails> purchaseDetailsList) {
        _handlePurchaseUpdates(purchaseDetailsList);
      },
      onDone: () {
        AppLogger.log('Purchase stream closed');
      },
      onError: (error) {
        AppLogger.log('Purchase stream error: $error');
      },
    );
  }

  /// Handle purchase updates from the platform
  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      try {
        AppLogger.log(
          'Processing purchase update: ${purchaseDetails.productID}',
        );

        if (purchaseDetails.productID == SubscriptionConfig.iosSubscriptionId ||
            purchaseDetails.productID ==
                SubscriptionConfig.androidSubscriptionId) {
          if (purchaseDetails.status == PurchaseStatus.purchased) {
            // Handle successful purchase
            if (io.Platform.isIOS) {
              await _appleService.handleApplePurchase(purchaseDetails);
            } else if (io.Platform.isAndroid) {
              await _googleService.handleGooglePurchase(purchaseDetails);
            }

            // Refresh subscription status
            await refreshSubscriptionStatus();

            _showSuccess('Subscription activated successfully!');
          } else if (purchaseDetails.status == PurchaseStatus.error) {
            AppLogger.log('Purchase error: ${purchaseDetails.error}');
            _showError(
              'Purchase failed: ${purchaseDetails.error?.message ?? "Unknown error"}',
            );
          } else if (purchaseDetails.status == PurchaseStatus.canceled) {
            AppLogger.log('Purchase cancelled by user');
            _showInfo('Purchase cancelled');
          } else if (purchaseDetails.status == PurchaseStatus.restored) {
            AppLogger.log('Purchase restored: ${purchaseDetails.productID}');
            await refreshSubscriptionStatus();
            _showSuccess('Subscription restored successfully!');
          }
        }

        // Complete the purchase if pending
        if (purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      } catch (e) {
        AppLogger.log('Error handling purchase update: $e');
      }
    }
  }

  /// Purchase subscription for current platform
  Future<void> purchaseSubscription() async {
    try {
      isLoading.value = true;
      AppLogger.log(
        'Starting subscription purchase for platform: ${currentPlatform.value}',
      );

      bool success = false;

      if (io.Platform.isIOS) {
        success = await _appleService.purchaseAppleSubscription();
      } else if (io.Platform.isAndroid) {
        success = await _googleService.purchaseGoogleSubscription();
      } else {
        _showError('Subscriptions not supported on this platform');
        return;
      }

      if (!success) {
        _showError('Failed to initiate subscription purchase');
      }
    } catch (e) {
      AppLogger.log('Error purchasing subscription: $e');
      _showError('Failed to purchase subscription');
    } finally {
      isLoading.value = false;
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    try {
      isLoading.value = true;
      AppLogger.log(
        'Restoring purchases for platform: ${currentPlatform.value}',
      );

      // Use the platform's restore purchases functionality
      await InAppPurchase.instance.restorePurchases();

      // Refresh subscription status
      await refreshSubscriptionStatus();

      if (isSubscriptionActive.value) {
        _showSuccess('Subscription restored successfully!');
      } else {
        _showInfo('No previous purchases found');
      }
    } catch (e) {
      AppLogger.log('Error restoring purchases: $e');
      _showError('Failed to restore purchases');
    } finally {
      isLoading.value = false;
    }
  }

  /// Refresh subscription status from platform-specific services
  Future<void> refreshSubscriptionStatus() async {
    try {
      AppLogger.log('Refreshing subscription status...');

      Map<String, dynamic> status = {};

      if (io.Platform.isIOS) {
        status = await _appleService.getAppleSubscriptionStatus();
      } else if (io.Platform.isAndroid) {
        status = await _googleService.getGoogleSubscriptionStatus();
      }

      // Update reactive variables
      isSubscriptionActive.value = status['isActive'] ?? false;
      subscriptionDetails.value = status;

      if (status['expiryDate'] != null) {
        expiryDate.value = DateTime.tryParse(status['expiryDate']);
      }

      subscriptionStatus.value =
          isSubscriptionActive.value ? 'active' : 'inactive';

      AppLogger.log('Subscription status updated: ${subscriptionStatus.value}');
    } catch (e) {
      AppLogger.log('Error refreshing subscription status: $e');
    }
  }

  /// Cancel subscription
  Future<void> cancelSubscription() async {
    try {
      isLoading.value = true;
      AppLogger.log(
        'Cancelling subscription for platform: ${currentPlatform.value}',
      );

      if (io.Platform.isIOS) {
        await _appleService.cancelAppleSubscription();
      } else if (io.Platform.isAndroid) {
        await _googleService.cancelGoogleSubscription();
      }

      // Refresh status after cancellation
      await refreshSubscriptionStatus();
    } catch (e) {
      AppLogger.log('Error cancelling subscription: $e');
      _showError('Failed to cancel subscription');
    } finally {
      isLoading.value = false;
    }
  }

  /// Get subscription plan details
  Map<String, dynamic> getSubscriptionPlan() {
    final productId =
        io.Platform.isIOS
            ? SubscriptionConfig.iosSubscriptionId
            : SubscriptionConfig.androidSubscriptionId;

    final plan = SubscriptionConfig.subscriptionPlans[productId];
    if (plan != null) {
      return {
        'id': plan.id,
        'name': plan.name,
        'description': plan.description,
        'duration': plan.duration,
        'isPopular': plan.isPopular,
        'price': '\$1.99',
        'features': [
          'Premium digital payment features',
          'Advanced transaction analytics',
          'Priority customer support',
          'Enhanced security features',
        ],
      };
    }

    return {
      'name': SubscriptionConfig.googlePlaySubscriptionName,
      'price': '\$1.99',
      'duration': 'month',
      'features': [
        'Premium digital payment features',
        'Advanced transaction analytics',
        'Priority customer support',
        'Enhanced security features',
      ],
    };
  }

  /// Get platform-specific subscription details
  Map<String, dynamic> getPlatformSubscriptionDetails() {
    return {
      'platform': currentPlatform.value,
      'productId':
          io.Platform.isIOS
              ? SubscriptionConfig.iosSubscriptionId
              : SubscriptionConfig.androidSubscriptionId,
      'isActive': isSubscriptionActive.value,
      'status': subscriptionStatus.value,
      'expiryDate': expiryDate.value?.toIso8601String(),
      'details': subscriptionDetails.value,
    };
  }

  /// Check if subscription is about to expire (within 7 days)
  bool isSubscriptionExpiringSoon() {
    if (expiryDate.value == null) return false;

    final now = DateTime.now();
    final daysUntilExpiry = expiryDate.value!.difference(now).inDays;

    return daysUntilExpiry <= 7 && daysUntilExpiry > 0;
  }

  /// Check if subscription has expired
  bool isSubscriptionExpired() {
    if (expiryDate.value == null) return false;

    return DateTime.now().isAfter(expiryDate.value!);
  }

  /// Get days until expiry
  int getDaysUntilExpiry() {
    if (expiryDate.value == null) return 0;

    return expiryDate.value!.difference(DateTime.now()).inDays;
  }

  /// Defer subscription (Android only)
  Future<void> deferSubscription(int deferralDays) async {
    if (!io.Platform.isAndroid) {
      _showError('Subscription deferral is only available on Android');
      return;
    }

    try {
      isLoading.value = true;
      await _googleService.deferGoogleSubscription(deferralDays);
      await refreshSubscriptionStatus();
    } catch (e) {
      AppLogger.log('Error deferring subscription: $e');
      _showError('Failed to defer subscription');
    } finally {
      isLoading.value = false;
    }
  }

  /// Show subscription management options
  void showSubscriptionManagement() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Get.theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subscription Management',
              style: Get.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildSubscriptionInfo(),
            const SizedBox(height: 20),
            _buildManagementButtons(),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  /// Build subscription info widget
  Widget _buildSubscriptionInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Get.theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isSubscriptionActive.value
                  ? Get.theme.colorScheme.primary
                  : Get.theme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSubscriptionActive.value ? Icons.check_circle : Icons.cancel,
                color:
                    isSubscriptionActive.value
                        ? Get.theme.colorScheme.primary
                        : Get.theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                isSubscriptionActive.value ? 'Active' : 'Inactive',
                style: Get.textTheme.titleMedium?.copyWith(
                  color:
                      isSubscriptionActive.value
                          ? Get.theme.colorScheme.primary
                          : Get.theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Platform: ${currentPlatform.value.toUpperCase()}',
            style: Get.textTheme.bodyMedium,
          ),
          if (expiryDate.value != null) ...[
            const SizedBox(height: 4),
            Text(
              'Expires: ${expiryDate.value!.toLocal().toString().split(' ')[0]}',
              style: Get.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  /// Build management buttons
  Widget _buildManagementButtons() {
    return Column(
      children: [
        if (!isSubscriptionActive.value) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: purchaseSubscription,
              child: const Text('Subscribe Now'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: restorePurchases,
            child: const Text('Restore Purchases'),
          ),
        ),
        if (isSubscriptionActive.value) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: cancelSubscription,
              style: OutlinedButton.styleFrom(
                foregroundColor: Get.theme.colorScheme.error,
                side: BorderSide(color: Get.theme.colorScheme.error),
              ),
              child: const Text('Cancel Subscription'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextButton(onPressed: () => Get.back(), child: const Text('Close')),
      ],
    );
  }

  /// Show success message
  void _showSuccess(String message) {
    Get.snackbar(
      'Success',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Get.theme.colorScheme.primary,
      colorText: Get.theme.colorScheme.onPrimary,
      icon: const Icon(Icons.check_circle, color: Colors.white),
    );
  }

  /// Show error message
  void _showError(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Get.theme.colorScheme.error,
      colorText: Get.theme.colorScheme.onError,
      icon: const Icon(Icons.error, color: Colors.white),
    );
  }

  /// Show info message
  void _showInfo(String message) {
    Get.snackbar(
      'Info',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Get.theme.colorScheme.secondary,
      colorText: Get.theme.colorScheme.onSecondary,
      icon: const Icon(Icons.info, color: Colors.white),
    );
  }
}
