import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../controller/subscription_controller.dart';
import '../screens/paywall_screen.dart';
import '../services/subscription_service.dart';
import '../utils/app_logger.dart';

/// Widget that guards access to premium features
/// Shows paywall if user doesn't have active subscription
class SubscriptionGuard extends StatefulWidget {
  final Widget child;
  final bool showLoadingOnCheck;
  final String? customMessage;

  const SubscriptionGuard({
    super.key,
    required this.child,
    this.showLoadingOnCheck = true,
    this.customMessage,
  });

  @override
  State<SubscriptionGuard> createState() => _SubscriptionGuardState();
}

class _SubscriptionGuardState extends State<SubscriptionGuard> {
  final SubscriptionController _subscriptionController =
      Get.find<SubscriptionController>();
  final SubscriptionService _subscriptionService = Get.find<SubscriptionService>();
  bool _isLoading = true;
  bool _hasSubscription = false;
  StreamSubscription<bool>? _subscriptionStatusSubscription;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
    _listenToSubscriptionChanges();
  }
  
  @override
  void dispose() {
    _subscriptionStatusSubscription?.cancel();
    super.dispose();
  }

  /// Listen to real-time subscription status changes
  void _listenToSubscriptionChanges() {
    _subscriptionStatusSubscription = _subscriptionService.subscriptionStatusStream.listen((hasSubscription) {
      if (mounted) {
        setState(() {
          _hasSubscription = hasSubscription;
          _isLoading = false;
        });
        AppLogger.log('Subscription status updated via stream: $hasSubscription');
      }
    });
  }

  Future<void> _checkSubscriptionStatus() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // CRITICAL FIX: Check cached status first for immediate response
      final cachedStatus = _subscriptionService.hasActiveSubscription;
      final controllerStatus = _subscriptionController.hasActiveSubscription;
      
      AppLogger.log(
        'SubscriptionGuard: Cached service status: $cachedStatus, Controller status: $controllerStatus',
      );
      
      // If both cached sources agree on active subscription, use it immediately
      if (cachedStatus && controllerStatus) {
        _hasSubscription = true;
        AppLogger.log('SubscriptionGuard: Both sources confirm active subscription, proceeding immediately');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Check subscription status with force refresh for accuracy
      final serviceStatus = await _subscriptionService.isUserSubscribed(
        forceRefresh: true,
      );
      
      // Re-check controller status after service refresh
      final updatedControllerStatus = _subscriptionController.hasActiveSubscription;

      AppLogger.log(
        'SubscriptionGuard: Service status after refresh: $serviceStatus, Updated controller status: $updatedControllerStatus',
      );

      // If there's still a mismatch, force controller to refresh
      if (serviceStatus != updatedControllerStatus) {
        AppLogger.log(
          'SubscriptionGuard: Status mismatch detected, forcing controller refresh',
        );
        await _subscriptionController.refreshData();
        
        // Give a moment for the controller to update
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _hasSubscription = serviceStatus;

      AppLogger.log(
        'SubscriptionGuard: Final subscription status: $_hasSubscription',
      );
    } catch (e) {
      AppLogger.log(
        'SubscriptionGuard: Error checking subscription status: $e',
      );
      // CRITICAL FIX: Don't assume false on error - check cached status
      _hasSubscription = _subscriptionService.hasActiveSubscription || _subscriptionController.hasActiveSubscription;
      AppLogger.log(
        'SubscriptionGuard: Using cached status due to error: $_hasSubscription',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showPaywall() {
    Get.to(
      () => const PaywallScreen(),
      fullscreenDialog: true,
      transition: Transition.cupertino,
    )?.then((_) {
      // Refresh subscription status when returning from paywall
      _checkSubscriptionStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && widget.showLoadingOnCheck) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: LoadingAnimationWidget.staggeredDotsWave(
            color: Theme.of(context).colorScheme.primary,
            size: 50,
          ),
        ),
      );
    }

    if (!_hasSubscription) {
      return _buildSubscriptionRequiredScreen();
    }

    return widget.child;
  }

  Widget _buildSubscriptionRequiredScreen() {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Premium Feature',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                widget.customMessage ??
                    'This feature requires an active subscription. Subscribe now to unlock all premium features.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _showPaywall,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Subscribe Now',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Refresh subscription status
                  _checkSubscriptionStatus();
                },
                child: Text(
                  'I already have a subscription',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mixin to easily add subscription checking to any widget
mixin SubscriptionMixin<T extends StatefulWidget> on State<T> {
  final SubscriptionController _subscriptionController =
      Get.find<SubscriptionController>();

  /// Check if user has active subscription
  Future<bool> checkSubscription({bool showPaywallIfNeeded = true}) async {
    try {
      final hasSubscription = _subscriptionController.hasActiveSubscription;

      if (!hasSubscription && showPaywallIfNeeded) {
        _showPaywall();
      }

      return hasSubscription;
    } catch (e) {
      AppLogger.log('Error checking subscription: $e');
      return false;
    }
  }

  /// Show paywall screen
  void _showPaywall() {
    Get.to(
      () => const PaywallScreen(),
      fullscreenDialog: true,
      transition: Transition.cupertino,
    );
  }

  /// Quick subscription check for button presses
  Future<bool> requiresSubscription(VoidCallback action) async {
    final hasSubscription = await checkSubscription();
    if (hasSubscription) {
      action();
      return true;
    }
    return false;
  }
}

/// Extension to add subscription checking to any BuildContext
extension SubscriptionContext on BuildContext {
  /// Check subscription and show paywall if needed
  Future<bool> requireSubscription({String? customMessage}) async {
    final subscriptionService = Get.find<SubscriptionService>();

    try {
      final hasSubscription = await subscriptionService.isUserSubscribed();

      if (!hasSubscription) {
        Get.to(
          () => const PaywallScreen(),
          fullscreenDialog: true,
          transition: Transition.cupertino,
        );
        return false;
      }

      return true;
    } catch (e) {
      AppLogger.log('Error checking subscription: $e');
      return false;
    }
  }
}
