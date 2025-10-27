import 'dart:io' as io;

/// Subscription product configuration for production
class SubscriptionConfig {
  // Platform-specific subscription product IDs
  static const String iosSubscriptionId = 'DP07071990';
  static const String androidSubscriptionId = '07071990';

  // Get the correct product ID based on platform
  static String get monthlySubscriptionId {
    return io.Platform.isIOS ? iosSubscriptionId : androidSubscriptionId;
  }

  // Apple App Store configuration
  static const String appleAppId = '6751464260';
  static const String appleReferenceName = 'Digital Payments -Premium';

  // Google Play Store configuration
  static const String googlePlaySubscriptionName = 'Digital Payments -Premium';

  // All available subscription products (platform-specific)
  static Set<String> get allProductIds {
    return {monthlySubscriptionId};
  }

  // Product metadata for UI display
  static Map<String, SubscriptionPlan> get subscriptionPlans {
    return {
      monthlySubscriptionId: SubscriptionPlan(
        id: monthlySubscriptionId,
        name: 'Digital Payments -Premium',
        description: 'Full access to all premium features for \$1.99/month',
        duration: 'Monthly',
        isPopular: true,
      ),
    };
  }

  // Get subscription plan by ID
  static SubscriptionPlan? getPlan(String productId) {
    return subscriptionPlans[productId];
  }

  // Get all available plans
  static List<SubscriptionPlan> getAllPlans() {
    return subscriptionPlans.values.toList();
  }

  // Get popular plan
  static SubscriptionPlan? getPopularPlan() {
    return subscriptionPlans.values.firstWhere(
      (plan) => plan.isPopular,
      orElse: () => subscriptionPlans.values.first,
    );
  }
}

/// Subscription plan model
class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final String duration;
  final bool isPopular;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.duration,
    required this.isPopular,
  });

  @override
  String toString() {
    return 'SubscriptionPlan(id: $id, name: $name, duration: $duration, isPopular: $isPopular)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubscriptionPlan && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
