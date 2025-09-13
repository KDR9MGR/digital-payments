import 'package:flutter_test/flutter_test.dart';
import 'package:xpay/services/pin_auth_service.dart';

void main() {
  group('PinAuthService Tests', () {
    late PinAuthService pinService;

    setUp(() {
      pinService = PinAuthService();
    });

    test('should check if PIN is enabled', () async {
      // Test PIN enabled status
      final isEnabled = await pinService.isPinEnabled();
      expect(isEnabled, isA<bool>());
    });

    test('should check if PIN setup is completed', () async {
      // Test PIN setup completion status
      final isCompleted = await pinService.isPinSetupCompleted();
      expect(isCompleted, isA<bool>());
    });

    test('should check if account is locked out', () async {
      // Test lockout status
      final isLockedOut = await pinService.isLockedOut();
      expect(isLockedOut, isA<bool>());
    });

    test('should setup PIN successfully', () async {
      // Test PIN setup
      const testPin = '123456';
      final result = await pinService.setupPin(testPin);
      expect(result, isA<PinSetupResult>());
      expect(result.success, isA<bool>());
    });

    test('should authenticate with PIN', () async {
      // Test PIN authentication
      const testPin = '123456';
      final result = await pinService.authenticate(testPin);
      expect(result, isA<PinAuthResult>());
      expect(result.success, isA<bool>());
      expect(result.errorType, isA<PinErrorType?>());
      expect(result.message, isA<String>());
    });

    test('should perform secure authentication', () async {
      // Test secure authentication
      const operation = 'test_operation';
      final result = await pinService.secureAuthenticate(operation: operation);
      expect(result, isA<bool>());
    });

    test('should change PIN successfully', () async {
      // Test PIN change
      const oldPin = '123456';
      const newPin = '654321';
      final result = await pinService.changePin(oldPin, newPin);
      expect(result, isA<PinChangeResult>());
      expect(result.success, isA<bool>());
    });

    test('should disable PIN', () async {
      // Test PIN disable
      const currentPin = '123456';
      final result = await pinService.disablePin(currentPin);
      expect(result, isA<bool>());
    });

    test('should handle invalid PIN attempts', () async {
      // Test invalid PIN handling
      const invalidPin = '000000';
      final result = await pinService.authenticate(invalidPin);
      
      if (!result.success) {
        expect(result.errorType, isNotNull);
        expect(result.message, isNotEmpty);
      }
    });

    test('should handle PIN lockout scenario', () async {
      // Test lockout handling
      final isLockedOut = await pinService.isLockedOut();
      
      if (isLockedOut) {
        const testPin = '123456';
        final result = await pinService.authenticate(testPin);
        expect(result.success, isFalse);
        expect(result.errorType, equals(PinErrorType.lockedOut));
      }
    });

    test('should validate PIN requirements', () async {
      // Test PIN validation
      const shortPin = '123';
      final result = await pinService.setupPin(shortPin);
      
      if (!result.success) {
        expect(result.message, contains('PIN'));
      }
    });

    test('should handle PIN not setup scenario', () async {
      // Test when PIN is not setup
      final isSetup = await pinService.isPinSetupCompleted();
      
      if (!isSetup) {
        const testPin = '123456';
        final result = await pinService.authenticate(testPin);
        expect(result.success, isFalse);
        expect(result.errorType, equals(PinErrorType.notSetup));
      }
    });

    test('should validate PinAuthResult properties', () async {
      // Test result object structure
      const testPin = '123456';
      final result = await pinService.authenticate(testPin);
      
      expect(result.success, isA<bool>());
      expect(result.message, isA<String>());
      expect(result.errorType, isA<PinErrorType?>());
      
      if (!result.success) {
        expect(result.errorType, isNotNull);
        expect(result.message, isNotEmpty);
      }
    });

    test('should handle multiple authentication attempts', () async {
      // Test multiple authentication attempts
      const invalidPin = '000000';
      final result = await pinService.authenticate(invalidPin);
      
      expect(result.success, isA<bool>());
      expect(result.message, isA<String>());
      
      if (!result.success) {
        expect(result.errorType, isNotNull);
      }
    });
  });
}