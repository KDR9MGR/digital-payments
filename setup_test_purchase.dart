import 'dart:convert';
import 'package:get_storage/get_storage.dart';

void main() async {
  print('=== Setting up test purchase data ===');

  // Initialize GetStorage
  await GetStorage.init();
  final storage = GetStorage();

  // Create mock purchase data
  final purchaseData = {
    'purchaseToken': 'test_purchase_token_active_subscription',
    'productId': 'super_payments_monthly',
    'purchaseTime':
        DateTime.now().subtract(Duration(days: 2)).millisecondsSinceEpoch,
  };

  // Store the purchase data
  storage.write('last_purchase_data', jsonEncode(purchaseData));

  print('✅ Stored test purchase data:');
  print('  - Purchase Token: ${purchaseData['purchaseToken']}');
  print('  - Product ID: ${purchaseData['productId']}');
  print(
    '  - Purchase Time: ${DateTime.fromMillisecondsSinceEpoch(purchaseData['purchaseTime'] as int)}',
  );

  // Also clear any existing client validation to force a fresh check
  storage.remove('client_validated_subscription');
  storage.remove('client_validation_date');
  storage.remove('subscription_status');

  print('\n✅ Cleared existing validation data');
  print(
    '\nNow run the app and it should detect the stored purchase and grant subscription access!',
  );
}
