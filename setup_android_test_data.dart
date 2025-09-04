import 'package:get_storage/get_storage.dart';
import 'dart:convert';

void main() async {
  await GetStorage.init();
  final storage = GetStorage();

  print('=== Setting up Android Test Purchase Data ===');

  // Create test purchase data for Android
  final testPurchaseData = {
    'purchaseToken': 'test_android_token_12345',
    'productId': 'premium_subscription_monthly',
    'purchaseTime':
        DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch,
  };

  // Store the purchase data
  storage.write('last_purchase_data', jsonEncode(testPurchaseData));

  // Clear any existing client validation to force fresh check
  storage.remove('client_validated_subscription');
  storage.remove('client_validation_date');
  storage.write('has_active_subscription', false);

  print('Test purchase data stored:');
  print('Purchase Token: ${testPurchaseData['purchaseToken']}');
  print('Product ID: ${testPurchaseData['productId']}');
  print(
    'Purchase Time: ${DateTime.fromMillisecondsSinceEpoch(testPurchaseData['purchaseTime'] as int)}',
  );

  // Verify the data was stored
  final storedData = storage.read('last_purchase_data');
  print('\nVerification - Stored data: $storedData');

  print('\n✅ Android test data setup complete!');
  print('Restart the app to test the enhanced client validation logic.');
}
