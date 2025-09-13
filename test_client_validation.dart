import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get_storage/get_storage.dart';

import 'lib/services/subscription_service.dart';
import 'lib/services/auth_service.dart';
import 'lib/controller/subscription_controller.dart';

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

    await testClientValidation();
  } catch (e) {
    print('Error initializing test script: $e');
  }
}

Future<void> testClientValidation() async {
  print('\n=== CLIENT VALIDATION TEST ===\n');

  try {
    final authService = Get.find<AuthService>();
    final subscriptionService = Get.find<SubscriptionService>();
    final storage = GetStorage();

    // Initialize services
    await subscriptionService.initialize();

    print('1. BEFORE TEST:');
    print('   - User signed in: ${authService.isSignedIn}');
    print(
      '   - Has subscription: ${await subscriptionService.isUserSubscribed()}',
    );
    print(
      '   - Client validated: ${storage.read('client_validated_subscription') ?? false}',
    );
    print(
      '   - Client validation date: ${storage.read('client_validation_date')}',
    );
    print('');

    // Simulate a client-validated subscription
    print('2. SIMULATING CLIENT-VALIDATED SUBSCRIPTION:');
    final now = DateTime.now();
    storage.write('client_validated_subscription', true);
    storage.write('client_validation_date', now.millisecondsSinceEpoch);
    print('   - Set client_validated_subscription: true');
    print(
      '   - Set client_validation_date: ${now.millisecondsSinceEpoch} ($now)',
    );
    print('');

    // Test subscription status with force refresh
    print('3. TESTING SUBSCRIPTION STATUS (Force Refresh):');
    final hasSubscription = await subscriptionService.isUserSubscribed(
      forceRefresh: true,
    );
    print('   - Force refresh result: $hasSubscription');
    print(
      '   - Service has active subscription: ${subscriptionService.hasActiveSubscription}',
    );
    print(
      '   - Has active subscription: ${subscriptionService.hasActiveSubscription}',
    );
    print('');

    // Test without force refresh
    print('4. TESTING SUBSCRIPTION STATUS (Cached):');
    final cachedResult = await subscriptionService.isUserSubscribed(
      forceRefresh: false,
    );
    print('   - Cached result: $cachedResult');
    print('');

    // Check storage after test
    print('5. AFTER TEST:');
    print(
      '   - Client validated: ${storage.read('client_validated_subscription') ?? false}',
    );
    print(
      '   - Client validation date: ${storage.read('client_validation_date')}',
    );
    print(
      '   - Subscription status key: ${storage.read('subscription_status') ?? false}',
    );
    print('');

    if (hasSubscription) {
      print('✅ SUCCESS: Client-validated subscription is working!');
    } else {
      print('❌ FAILED: Client-validated subscription is not being recognized');

      // Additional debugging
      print('');
      print('DEBUGGING INFO:');
      final validationDate = storage.read('client_validation_date');
      if (validationDate != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(validationDate);
        final expiryDate = date.add(const Duration(days: 30));
        final isExpired = DateTime.now().isAfter(expiryDate);
        print('   - Validation date: $date');
        print('   - Expiry date: $expiryDate');
        print('   - Is expired: $isExpired');
        print(
          '   - Days until expiry: ${expiryDate.difference(DateTime.now()).inDays}',
        );
      }
    }
  } catch (e, stackTrace) {
    print('ERROR during test: $e');
    print('Stack trace: $stackTrace');
  }

  print('\n=== TEST COMPLETE ===\n');
}
