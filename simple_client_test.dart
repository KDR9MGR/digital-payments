import 'dart:io';

void main() async {
  print('=== Client Validation Test ===');

  // Simulate the storage values that would be set by client validation
  final now = DateTime.now();
  final validationDate = now.millisecondsSinceEpoch;
  final expiryDate = now.add(Duration(days: 30));

  print('Current time: $now');
  print(
    'Validation date: ${DateTime.fromMillisecondsSinceEpoch(validationDate)}',
  );
  print('Expiry date: $expiryDate');
  print('Days until expiry: ${expiryDate.difference(now).inDays}');

  // Test the expiry logic
  final isExpired = now.isAfter(expiryDate);
  final isValid = !isExpired;

  print('\n=== Validation Results ===');
  print('Is expired: $isExpired');
  print('Is valid: $isValid');
  print('Should grant subscription: $isValid');

  // Test with an expired subscription (31 days ago)
  final expiredValidationDate =
      now.subtract(Duration(days: 31)).millisecondsSinceEpoch;
  final expiredExpiryDate = DateTime.fromMillisecondsSinceEpoch(
    expiredValidationDate,
  ).add(Duration(days: 30));
  final isExpiredTest = now.isAfter(expiredExpiryDate);

  print('\n=== Expired Subscription Test ===');
  print(
    'Expired validation date: ${DateTime.fromMillisecondsSinceEpoch(expiredValidationDate)}',
  );
  print('Expired expiry date: $expiredExpiryDate');
  print('Is expired: $isExpiredTest');
  print('Should grant subscription: ${!isExpiredTest}');

  print('\n=== Test Complete ===');
}
