import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:convert';

import 'services/subscription_service.dart';
import 'services/auth_service.dart';
import 'controller/subscription_controller.dart';
import 'utils/app_logger.dart';
import 'config/subscription_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp();

    // Initialize GetStorage
    await GetStorage.init();

    // Initialize services
    Get.put(AuthService());
    Get.put(SubscriptionService());
    Get.put(SubscriptionController());

    // Setup test purchase data for Android
    await setupTestPurchaseData();

    await debugSubscriptionStatus();
  } catch (e) {
    print('Error initializing debug script: $e');
  }
}

Future<void> debugSubscriptionStatus() async {
  print('\n=== SUBSCRIPTION DEBUG REPORT ===\n');

  try {
    final authService = Get.find<AuthService>();
    final subscriptionService = Get.find<SubscriptionService>();
    final subscriptionController = Get.find<SubscriptionController>();

    // Initialize services
    await subscriptionService.initialize();

    print('1. AUTHENTICATION STATUS:');
    print('   - User signed in: ${authService.isSignedIn}');
    print('   - Current user: ${authService.currentUser?.uid ?? "None"}');
    print('');

    print('2. CONFIGURED PRODUCT IDs:');
    print('   - iOS Subscription ID: ${SubscriptionConfig.iosSubscriptionId}');
    print(
      '   - Android Subscription ID: ${SubscriptionConfig.androidSubscriptionId}',
    );
    print(
      '   - Monthly Subscription ID: ${SubscriptionConfig.monthlySubscriptionId}',
    );
    print('   - All Product IDs: ${SubscriptionConfig.allProductIds}');
    print('');

    print('3. LOCAL STORAGE STATUS:');
    final storage = GetStorage();
    final localStatus = storage.read('subscription_status');
    final lastCheck = storage.read('last_subscription_check');
    final subscriptionExpiry = storage.read('subscription_expiry');

    print('   - Local subscription status: $localStatus');
    print('   - Last check timestamp: $lastCheck');
    print('   - Subscription expiry: $subscriptionExpiry');
    print('');

    print('4. SUBSCRIPTION SERVICE STATUS:');
    print(
      '   - Has active subscription (cached): ${subscriptionService.hasActiveSubscription}',
    );
    print('   - Is in grace period: ${subscriptionService.isInGracePeriod}');
    print(
      '   - Should check subscription: ${subscriptionService.shouldCheckSubscription()}',
    );
    print('');

    print('5. SUBSCRIPTION VALIDATION (Force Refresh):');
    if (authService.isSignedIn) {
      final hasSubscription = await subscriptionService.isUserSubscribed(
        forceRefresh: true,
      );
      print('   - Force refresh result: $hasSubscription');
    } else {
      print('   - Skipped (user not authenticated)');
    }
    print('');

    print('6. CONTROLLER STATUS:');
    print(
      '   - Controller has subscription: ${subscriptionController.hasActiveSubscription}',
    );
    print('   - Controller is loading: ${subscriptionController.isLoading}');
    print('');

    print('=== TROUBLESHOOTING STEPS ===\n');

    if (!authService.isSignedIn) {
      print('❌ User is not authenticated. Please sign in first.');
    } else if (!subscriptionService.hasActiveSubscription) {
      print('❌ No active subscription found.');
      print('   - Check if the purchase was completed successfully');
      print('   - Verify the product ID matches the configured IDs');
      print('   - Check if the purchase receipt was validated with the server');
    } else {
      print('✅ Subscription appears to be active.');
      print('   - If paywall still appears, check the UI logic');
      print('   - Verify subscription guard is using the correct service');
    }
  } catch (e, stackTrace) {
    print('ERROR during debug: $e');
    print('Stack trace: $stackTrace');
  }

  print('\n=== DEBUG COMPLETE ===\n');
}

Future<void> setupTestPurchaseData() async {
  print('Setting up test purchase data for Android...');

  final storage = GetStorage();

  // Clear existing client validation data
  await storage.remove('client_validated_subscription');
  await storage.remove('client_validation_date');
  await storage.remove('has_active_subscription');
  await storage.remove('subscription_expiry');

  // Create test purchase data
  final testPurchaseData = {
    'purchaseToken': 'test_purchase_token_android_12345',
    'productId': '07071990',
    'purchaseTime':
        DateTime.now().subtract(Duration(days: 2)).millisecondsSinceEpoch,
  };

  // Store the test purchase data
  await storage.write('last_purchase_data', json.encode(testPurchaseData));

  print('Test purchase data stored:');
  print('  - Purchase Token: ${testPurchaseData['purchaseToken']}');
  print('  - Product ID: ${testPurchaseData['productId']}');
  print(
    '  - Purchase Time: ${DateTime.fromMillisecondsSinceEpoch(testPurchaseData['purchaseTime'] as int)}',
  );
  print('Test data setup complete.\n');
}
