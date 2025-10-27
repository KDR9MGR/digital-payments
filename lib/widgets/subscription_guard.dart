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
  bool _isLoading = false;
  bool _hasSubscription = true; // Subscription features disabled - always grant access

  @override
  void initState() {
    super.initState();
    // Subscription features disabled - no need to check status
  }
  
  @override
  void dispose() {
    super.dispose();
  }

  /// Subscription features disabled - no need to listen to changes
  void _listenToSubscriptionChanges() {
    // Subscription features disabled - no action needed
  }

  Future<void> _checkSubscriptionStatus() async {
    // Subscription features disabled - always grant access
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _hasSubscription = true;
    });
  }

  void _showPaywall() {
    // Subscription features disabled - no paywall needed
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
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: null, // Disabled since subscription features are disabled
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Subscription Disabled',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Subscription features disabled - grant access
                  setState(() {
                    _hasSubscription = true;
                  });
                },
                child: Text(
                  'Continue without subscription',
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
  /// Check if user has active subscription - always returns true since subscription features are disabled
  Future<bool> checkSubscription({bool showPaywallIfNeeded = true}) async {
    return true;
  }

  /// Show paywall screen - disabled
  void _showPaywall() {
    // Subscription features disabled - no paywall needed
  }

  /// Quick subscription check for button presses - always executes action
  Future<bool> requiresSubscription(VoidCallback action) async {
    action();
    return true;
  }
}

/// Extension to add subscription checking to any BuildContext
extension SubscriptionContext on BuildContext {
  /// Check subscription and show paywall if needed - always returns true since subscription features are disabled
  Future<bool> requireSubscription({String? customMessage}) async {
    return true;
  }
}
