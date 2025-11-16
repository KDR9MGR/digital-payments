import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../mocks/mock_pin_auth_service.dart';
import '../mocks/mock_error_handling_service.dart';

void main() {
  group('PinAuthService Tests', () {
    late MockPinAuthService pinAuthService;
    late MockErrorHandlingService errorHandlingService;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      Get.testMode = true;
    });

    setUp(() async {
      // Reset GetX state
      Get.reset();
      Get.testMode = true;
      
      // Initialize mock services
      pinAuthService = MockPinAuthService();
      errorHandlingService = MockErrorHandlingService();
      
      // Reset mock state
      pinAuthService.resetMockState();
      
      // Initialize the service
      await pinAuthService.initialize();
    });

    tearDown(() async {
      // Clean up
      await pinAuthService.invalidateSession();
      Get.reset();
    });

    group('PIN Status Checks', () {
      test('should return false for PIN enabled when not set up', () async {
        final isEnabled = await pinAuthService.isPinEnabled();
        expect(isEnabled, isFalse);
      });

      test('should return false for PIN setup completed when not set up', () async {
        final isSetupCompleted = await pinAuthService.isPinSetupCompleted();
        expect(isSetupCompleted, isFalse);
      });

      test('should return false for lockout when not locked', () async {
        final isLockedOut = await pinAuthService.isLockedOut();
        expect(isLockedOut, isFalse);
      });

      test('should return null for remaining lockout time when not locked', () async {
        final remainingTime = await pinAuthService.getRemainingLockoutTime();
        expect(remainingTime, isNull);
      });
    });

    group('PIN Setup', () {
      test('should successfully set up a valid PIN', () async {
        const validPin = '123456';
        
        final result = await pinAuthService.setupPin(validPin);
        
        expect(result['success'], isTrue);
        expect(result['message'], contains('successfully'));
        
        // Verify PIN is now enabled and setup completed
        expect(await pinAuthService.isPinEnabled(), isTrue);
        expect(await pinAuthService.isPinSetupCompleted(), isTrue);
      });

      test('should reject PIN that is too short', () async {
        const shortPin = '123';
        
        final result = await pinAuthService.setupPin(shortPin);
        
        expect(result['success'], isFalse);
        expect(result['message'], contains('at least 4 digits'));
      });

      test('should reject PIN that is too long', () async {
        const longPin = '123456789';
        
        final result = await pinAuthService.setupPin(longPin);
        
        expect(result['success'], isFalse);
        expect(result['message'], contains('at most 8 digits'));
      });

      test('should reject weak PIN patterns', () async {
        const weakPins = ['1111', '1234', '0000'];
        
        for (final pin in weakPins) {
          final result = await pinAuthService.setupPin(pin);
          expect(result['success'], isFalse);
          expect(result['message'], contains('weak'));
        }
      });
    });

    group('PIN Authentication', () {
      setUp(() async {
        // Set up a PIN for authentication tests
        await pinAuthService.setupPin('123456');
      });

      test('should authenticate with correct PIN', () async {
        final result = await pinAuthService.authenticate('123456');
        
        expect(result['success'], isTrue);
        expect(result['message'], contains('successful'));
        expect(result['errorType'], isNull);
      });

      test('should reject incorrect PIN', () async {
        final result = await pinAuthService.authenticate('654321');
        
        expect(result['success'], isFalse);
        expect(result['errorType'], equals('incorrect_pin'));
        expect(result['message'], contains('Incorrect PIN'));
      });

      test('should handle sensitive transaction authentication', () async {
        // First authenticate normally
        await pinAuthService.authenticate('123456');
        
        // Sensitive transaction should require fresh authentication
        final result = await pinAuthService.authenticate('123456', sensitiveTransaction: true);
        
        expect(result['success'], isTrue);
      });

      test('should use cached authentication for non-sensitive operations', () async {
        // First authenticate
        await pinAuthService.authenticate('123456');
        
        // Second authentication should use cache
        final result = await pinAuthService.authenticate('123456', sensitiveTransaction: false);
        
        expect(result['success'], isTrue);
        expect(result['message'], contains('cached'));
      });
    });

    group('PIN Change', () {
      setUp(() async {
        // Set up initial PIN
        await pinAuthService.setupPin('123456');
      });

      test('should successfully change PIN with correct current PIN', () async {
        final result = await pinAuthService.changePin('123456', '654321');
        
        expect(result['success'], isTrue);
        expect(result['message'], contains('successfully'));
        
        // Verify new PIN works
        final authResult = await pinAuthService.authenticate('654321');
        expect(authResult['success'], isTrue);
      });

      test('should reject change with incorrect current PIN', () async {
        final result = await pinAuthService.changePin('wrong', '654321');
        
        expect(result['success'], isFalse);
        expect(result['message'], contains('Current PIN is incorrect'));
      });

      test('should reject change when new PIN is same as current', () async {
        final result = await pinAuthService.changePin('123456', '123456');
        
        expect(result['success'], isFalse);
        expect(result['message'], contains('must be different'));
      });

      test('should reject weak new PIN', () async {
        final result = await pinAuthService.changePin('123456', '1111');
        
        expect(result['success'], isFalse);
        expect(result['message'], contains('weak'));
      });
    });

    group('PIN Disable', () {
      setUp(() async {
        // Set up PIN for disable tests
        await pinAuthService.setupPin('123456');
      });

      test('should successfully disable PIN with correct PIN', () async {
        final result = await pinAuthService.disablePin('123456');
        
        expect(result['success'], isTrue);
        
        // Verify PIN is disabled
        expect(await pinAuthService.isPinEnabled(), isFalse);
      });

      test('should reject disable with incorrect PIN', () async {
        final result = await pinAuthService.disablePin('wrong');
        
        expect(result['success'], isFalse);
        
        // Verify PIN is still enabled
        expect(await pinAuthService.isPinEnabled(), isTrue);
      });
    });

    group('Failed Attempts and Lockout', () {
      setUp(() async {
        // Set up PIN for lockout tests
        await pinAuthService.setupPin('123456');
      });

      test('should track failed attempts', () async {
        // Make multiple failed attempts
        for (int i = 0; i < 3; i++) {
          final result = await pinAuthService.authenticate('wrong');
          expect(result['success'], isFalse);
          expect(result['message'], contains('attempts remaining'));
        }
      });

      test('should lockout after max failed attempts', () async {
        // Make max failed attempts (5)
        for (int i = 0; i < 5; i++) {
          await pinAuthService.authenticate('wrong');
        }
        
        // Next attempt should show lockout
        final result = await pinAuthService.authenticate('wrong');
        expect(result['success'], isFalse);
        expect(result['errorType'], equals('locked_out'));
        expect(result['message'], contains('locked'));
        
        // Verify lockout status
        expect(await pinAuthService.isLockedOut(), isTrue);
        expect(await pinAuthService.getRemainingLockoutTime(), isNotNull);
      });

      test('should reject authentication when locked out', () async {
        // Trigger lockout
        for (int i = 0; i < 5; i++) {
          await pinAuthService.authenticate('wrong');
        }
        
        // Try to authenticate with correct PIN while locked out
        final result = await pinAuthService.authenticate('123456');
        expect(result['success'], isFalse);
        expect(result['errorType'], equals('locked_out'));
      });
    });

    group('PIN Validation', () {
      test('should validate PIN length requirements', () async {
        // Test short PIN
        final shortResult = await pinAuthService.setupPin('12');
        expect(shortResult['success'], isFalse);
        
        // Test long PIN
        final longResult = await pinAuthService.setupPin('123456789');
        expect(longResult['success'], isFalse);
        
        // Test valid PIN
        final validResult = await pinAuthService.setupPin('1357');
        expect(validResult['success'], isTrue);
      });
    });

    group('Session Management', () {
      setUp(() async {
        await pinAuthService.setupPin('123456');
      });

      test('should invalidate session', () async {
        // Authenticate first
        await pinAuthService.authenticate('123456');
        
        // Invalidate session
        await pinAuthService.invalidateSession();
        
        // Check session is invalid
        expect(pinAuthService.isSessionValid(), isFalse);
      });

      test('should check session validity', () async {
        // Initially no session
        expect(pinAuthService.isSessionValid(), isFalse);
        
        // After authentication, session should be valid
        await pinAuthService.authenticate('123456');
        expect(pinAuthService.isSessionValid(), isTrue);
      });

      test('should get session time remaining', () async {
        // Initially no session
        expect(pinAuthService.getSessionTimeRemaining(), isNull);
        
        // After authentication, should have time remaining
        await pinAuthService.authenticate('123456');
        expect(pinAuthService.getSessionTimeRemaining(), isNotNull);
      });
    });

    group('Quick and Secure Authentication', () {
      setUp(() async {
        await pinAuthService.setupPin('123456');
      });

      test('should handle quick authentication method', () async {
        // Initially should be false
        expect(await pinAuthService.quickAuthenticate(), isFalse);
        
        // After authentication, should be true
        await pinAuthService.authenticate('123456');
        expect(await pinAuthService.quickAuthenticate(), isTrue);
      });

      test('should handle secure authentication method', () async {
        final result = await pinAuthService.secureAuthenticate('123456', operation: 'transfer money');
        expect(result['success'], isTrue);
      });
    });

    group('Mock State Management', () {
      test('should reset mock state', () {
        pinAuthService.setMockPinEnabled(true);
        pinAuthService.setMockSetupCompleted(true);
        
        pinAuthService.resetMockState();
        
        expect(pinAuthService.isPinEnabled(), completion(isFalse));
        expect(pinAuthService.isPinSetupCompleted(), completion(isFalse));
      });

      test('should set mock PIN enabled state', () {
        pinAuthService.setMockPinEnabled(true);
        expect(pinAuthService.isPinEnabled(), completion(isTrue));
        
        pinAuthService.setMockPinEnabled(false);
        expect(pinAuthService.isPinEnabled(), completion(isFalse));
      });

      test('should set mock setup completed state', () {
        pinAuthService.setMockSetupCompleted(true);
        expect(pinAuthService.isPinSetupCompleted(), completion(isTrue));
        
        pinAuthService.setMockSetupCompleted(false);
        expect(pinAuthService.isPinSetupCompleted(), completion(isFalse));
      });

      test('should set mock failed attempts', () async {
        await pinAuthService.setupPin('123456');
        
        pinAuthService.setMockFailedAttempts(3);
        
        final result = await pinAuthService.authenticate('9999');
        expect(result['remainingAttempts'], equals(1)); // 5 - 4 (3 + 1 new failure)
      });

      test('should set mock lockout time', () async {
        final lockoutTime = DateTime.now();
        pinAuthService.setMockLockoutTime(lockoutTime);
        
        expect(await pinAuthService.isLockedOut(), isTrue);
        expect(await pinAuthService.getRemainingLockoutTime(), isNotNull);
      });

      test('should setup mock PIN for testing', () async {
        pinAuthService.setupMockPin('999999');
        
        expect(await pinAuthService.isPinEnabled(), isTrue);
        expect(await pinAuthService.isPinSetupCompleted(), isTrue);
        
        final result = await pinAuthService.authenticate('999999');
        expect(result['success'], isTrue);
      });
    });

    group('Service Lifecycle', () {
      test('should be singleton instance', () {
        final instance1 = MockPinAuthService();
        final instance2 = MockPinAuthService();
        
        expect(identical(instance1, instance2), isTrue);
      });

      test('should initialize properly', () async {
        expect(() async {
          await pinAuthService.initialize();
        }, returnsNormally);
      });
    });
  });
}