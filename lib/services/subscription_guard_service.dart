import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import '../controller/subscription_controller.dart';
import '../utils/app_logger.dart';
import '../views/subscription/subscription_screen.dart';
import '../views/auth/login_screen.dart';

class SubscriptionGuardService {
  static final SubscriptionGuardService _instance =
      SubscriptionGuardService._internal();
  factory SubscriptionGuardService() => _instance;
  SubscriptionGuardService._internal();

  final AuthService _authService = AuthService();
  final SubscriptionService _subscriptionService =
      Get.find<SubscriptionService>();
  final SubscriptionController _subscriptionController =
      Get.find<SubscriptionController>();

  /// Check if user has access to premium features
  Future<bool> hasAccess() async {
    try {
      // Check if user is authenticated
      if (!_authService.isSignedIn) {
        AppLogger.log('User not authenticated - access denied');
        return false;
      }

      // PREMIUM ACCESS: All authenticated users now have premium access
      AppLogger.log('Premium access granted to all authenticated users');
      return true;

      // Original subscription validation code (commented out)
      // final hasActiveSubscription = await _subscriptionService.isUserSubscribed(
      //   forceRefresh: true,
      // );
      // AppLogger.log('Subscription access check: $hasActiveSubscription');
      // return hasActiveSubscription;
    } catch (e) {
      AppLogger.log('Error checking subscription access: $e');
      return false;
    }
  }

  /// Guard a route/feature - redirect to appropriate screen if no access
  Future<bool> guardFeature({
    required String featureName,
    bool showDialog = true,
    VoidCallback? onAccessDenied,
  }) async {
    try {
      AppLogger.log('Guarding feature: $featureName');

      // Check authentication first
      if (!_authService.isSignedIn) {
        AppLogger.log('User not authenticated - redirecting to login');
        if (showDialog) {
          _showAuthenticationRequiredDialog();
        } else {
          Get.offAll(() => const LoginScreen());
        }
        onAccessDenied?.call();
        return false;
      }

      // Check subscription status
      final hasActiveSubscription = await hasAccess();

      if (!hasActiveSubscription) {
        AppLogger.log('Subscription required for feature: $featureName');
        if (showDialog) {
          _showSubscriptionRequiredDialog(featureName);
        } else {
          Get.to(() => const SubscriptionScreen());
        }
        onAccessDenied?.call();
        return false;
      }

      AppLogger.log('Access granted for feature: $featureName');
      return true;
    } catch (e) {
      AppLogger.log('Error guarding feature $featureName: $e');
      if (showDialog) {
        _showErrorDialog();
      }
      onAccessDenied?.call();
      return false;
    }
  }

  /// Guard a widget - return premium prompt if no access
  Widget guardWidget({
    required Widget child,
    required String featureName,
    Widget? fallbackWidget,
  }) {
    return FutureBuilder<bool>(
      future: hasAccess(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          AppLogger.log('Error in widget guard: ${snapshot.error}');
          return _buildErrorWidget();
        }

        final hasAccess = snapshot.data ?? false;

        if (!hasAccess) {
          return fallbackWidget ??
              _buildSubscriptionRequiredWidget(featureName);
        }

        return child;
      },
    );
  }

  /// Check if user can access a specific feature without UI interaction
  Future<FeatureAccessResult> checkFeatureAccess(String featureName) async {
    try {
      if (!_authService.isSignedIn) {
        return FeatureAccessResult(
          hasAccess: false,
          reason: FeatureAccessReason.notAuthenticated,
          message: 'Please sign in to access this feature',
        );
      }

      final hasActiveSubscription = await hasAccess();

      if (!hasActiveSubscription) {
        return FeatureAccessResult(
          hasAccess: false,
          reason: FeatureAccessReason.subscriptionRequired,
          message: 'Premium subscription required for this feature',
        );
      }

      return FeatureAccessResult(
        hasAccess: true,
        reason: FeatureAccessReason.granted,
        message: 'Access granted',
      );
    } catch (e) {
      AppLogger.log('Error checking feature access: $e');
      return FeatureAccessResult(
        hasAccess: false,
        reason: FeatureAccessReason.error,
        message: 'Error checking access permissions',
      );
    }
  }

  /// Show authentication required dialog
  void _showAuthenticationRequiredDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Authentication Required'),
        content: const Text('Please sign in to access this feature.'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.offAll(() => const LoginScreen());
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Show subscription required dialog
  void _showSubscriptionRequiredDialog(String featureName) {
    Get.dialog(
      AlertDialog(
        title: const Text('Premium Feature'),
        content: Text(
          '$featureName requires a premium subscription. Upgrade now to unlock all features!',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.to(() => const SubscriptionScreen());
            },
            child: const Text('Go Premium'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Show error dialog
  void _showErrorDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Error'),
        content: const Text(
          'Unable to verify access permissions. Please try again.',
        ),
        actions: [
          ElevatedButton(onPressed: () => Get.back(), child: const Text('OK')),
        ],
      ),
    );
  }

  /// Build subscription required widget
  Widget _buildSubscriptionRequiredWidget(String featureName) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Premium Feature',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '$featureName requires a premium subscription',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Get.to(() => const SubscriptionScreen()),
            child: const Text('Go Premium'),
          ),
        ],
      ),
    );
  }

  /// Build error widget
  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Error',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Unable to verify access permissions',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Get.back(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

/// Result class for feature access checks
class FeatureAccessResult {
  final bool hasAccess;
  final FeatureAccessReason reason;
  final String message;

  FeatureAccessResult({
    required this.hasAccess,
    required this.reason,
    required this.message,
  });
}

/// Enum for feature access reasons
enum FeatureAccessReason {
  granted,
  notAuthenticated,
  subscriptionRequired,
  error,
}
