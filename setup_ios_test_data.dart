import 'dart:io';
import 'dart:convert';

void main() {
  final storageFile = File(
    '/Users/abdulrazak/Library/Developer/CoreSimulator/Devices/1C37142A-6E2B-4AE8-82D1-6F3FA30E2681/data/Containers/Data/Application/2B64BF2A-241B-4937-A323-6E09708D2706/Documents/GetStorage.gs',
  );

  // Create test purchase data
  final testPurchaseData = {
    'purchaseToken': 'test_token_12345',
    'productId': 'premium_subscription_monthly',
    'purchaseTime':
        DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch,
  };

  // Create storage data
  final storageData = {
    'last_purchase_data': jsonEncode(testPurchaseData),
    // Clear any existing client validation to force fresh check
    'client_validated_subscription': null,
    'client_validation_date': null,
    'has_active_subscription': false,
  };

  // Write to storage file
  storageFile.writeAsStringSync(jsonEncode(storageData));

  print('Test purchase data written to iOS simulator storage:');
  print('Purchase Token: ${testPurchaseData['purchaseToken']}');
  print('Product ID: ${testPurchaseData['productId']}');
  print(
    'Purchase Time: ${DateTime.fromMillisecondsSinceEpoch(testPurchaseData['purchaseTime'] as int)}',
  );
  print('\nStorage file updated: ${storageFile.path}');
}
