import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lib/services/subscription_service.dart';
import 'lib/config/subscription_config.dart';
import 'lib/utils/app_logger.dart';

/// Debug script to check subscription status and identify issues
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize GetStorage
  await GetStorage.init();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Get
  Get.put(SubscriptionService());

  print('=== SUBSCRIPTION DEBUG TOOL ===');
  print('');

  // Check current user
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('❌ No authenticated user found');
    print('Please log in to the app first, then run this debug script.');
    exit(1);
  }

  print('✅ Authenticated user: ${user.uid}');
  print('📧 Email: ${user.email}');
  print('');

  // Check configured product IDs
  print('📦 Configured Product IDs:');
  print('  - iOS: ${SubscriptionConfig.iosSubscriptionId}');
  print('  - Android: ${SubscriptionConfig.androidSubscriptionId}');
  print('  - Current Platform: ${SubscriptionConfig.monthlySubscriptionId}');
  print('');

  // Check local storage
  final storage = GetStorage();
  final localStatus = storage.read('subscription_status') ?? false;
  final lastCheck = storage.read('last_subscription_check');

  print('💾 Local Storage Status:');
  print('  - Subscription Status: $localStatus');
  print(
    '  - Last Check: ${lastCheck != null ? DateTime.fromMillisecondsSinceEpoch(lastCheck) : "Never"} ',
  );
  print('');

  // Check subscription service status
  final subscriptionService = Get.find<SubscriptionService>();

  print('🔍 Checking Subscription Service Status...');
  try {
    // Initialize the service
    await subscriptionService.initialize();

    // Check subscription status without force refresh first
    final statusWithoutRefresh = await subscriptionService.isUserSubscribed(
      forceRefresh: false,
    );
    print('  - Status (cached): $statusWithoutRefresh');

    // Check subscription status with force refresh
    final statusWithRefresh = await subscriptionService.isUserSubscribed(
      forceRefresh: true,
    );
    print('  - Status (force refresh): $statusWithRefresh');

    // Check if service is available
    print('  - Service Available: ${subscriptionService.isAvailable}');
    print('  - Products Loaded: ${subscriptionService.products.length}');

    if (subscriptionService.products.isNotEmpty) {
      print('  - Available Products:');
      for (final product in subscriptionService.products) {
        print('    * ${product.id}: ${product.title} - ${product.price}');
      }
    }
  } catch (e) {
    print('❌ Error checking subscription service: $e');
  }

  print('');
  print('🔧 Troubleshooting Steps:');
  print(
    '1. Check if the purchased product ID matches the configured product ID',
  );
  print(
    '2. Verify that the purchase was completed successfully in the app store',
  );
  print('3. Check if the Firebase backend validation is working');
  print('4. Try logging out and logging back in');
  print('5. Try clearing app data and re-purchasing (test environment only)');
  print('');
  print('📝 If the issue persists, check the app logs for DEBUG messages');
  print('   Look for messages starting with "DEBUG:" in the console output');

  exit(0);
}
