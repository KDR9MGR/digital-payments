import 'dart:convert';
import 'dart:io';

void main() async {
  print('=== Testing Stored Purchase Data Validation ===');

  // Simulate stored purchase data that would be saved after a successful purchase
  final purchaseData = {
    'purchaseToken': 'mock_purchase_token_12345',
    'productId':
        'super_payments_monthly', // This should be in the product IDs list
    'purchaseTime':
        DateTime.now()
            .subtract(Duration(days: 5))
            .millisecondsSinceEpoch, // 5 days ago
  };

  final storedPurchaseDataJson = jsonEncode(purchaseData);

  print('Simulated stored purchase data:');
  print('  - Purchase Token: ${purchaseData['purchaseToken']}');
  print('  - Product ID: ${purchaseData['productId']}');
  print(
    '  - Purchase Time: ${DateTime.fromMillisecondsSinceEpoch(purchaseData['purchaseTime'] as int)}',
  );
  print('  - JSON: $storedPurchaseDataJson');

  // Test the validation logic
  print('\n=== Validation Logic Test ===');

  // Simulate the product IDs list (from SubscriptionConfig)
  final productIds = {
    'super_payments_monthly',
    'premium_monthly',
    'basic_monthly',
  };

  try {
    final parsedData = jsonDecode(storedPurchaseDataJson);
    final purchaseToken = parsedData['purchaseToken'];
    final productId = parsedData['productId'];

    print('Parsed data:');
    print('  - Purchase Token: $purchaseToken');
    print('  - Product ID: $productId');
    print('  - Product ID in list: ${productIds.contains(productId)}');

    if (purchaseToken != null && productIds.contains(productId)) {
      print('\n✅ Validation would succeed!');
      print('Would grant 30-day client-side subscription');

      final now = DateTime.now();
      final expiryDate = now.add(Duration(days: 30));

      print('  - Current time: $now');
      print('  - Expiry date: $expiryDate');
      print('  - Days until expiry: ${expiryDate.difference(now).inDays}');

      // Simulate storage writes
      print('\nWould write to storage:');
      print('  - client_validated_subscription: true');
      print('  - client_validation_date: ${now.millisecondsSinceEpoch}');
      print('  - subscription_status: true');
    } else {
      print('\n❌ Validation would fail!');
      if (purchaseToken == null) {
        print('  - Reason: No purchase token');
      }
      if (!productIds.contains(productId)) {
        print('  - Reason: Product ID not in subscription list');
      }
    }
  } catch (e) {
    print('\n❌ Error parsing stored data: $e');
  }

  print('\n=== Test Complete ===');
}
