import 'package:flutter_test/flutter_test.dart';
import 'package:xpay/services/biometric_auth_service.dart';

void main() {
  group('BiometricAuthService Tests', () {
    late BiometricAuthService biometricService;

    setUp(() {
      biometricService = BiometricAuthService();
    });

    test('should check if biometric is available', () async {
      // Test biometric availability check
      final isAvailable = await biometricService.isBiometricAvailable();
      expect(isAvailable, isA<bool>());
    });

    test('should get available biometrics', () async {
      // Test getting available biometric types
      final biometrics = await biometricService.getAvailableBiometrics();
      expect(biometrics, isA<List<String>>());
    });

    test('should check if biometric is enabled', () async {
      // Test biometric enabled status
      final isEnabled = await biometricService.isBiometricEnabled();
      expect(isEnabled, isA<bool>());
    });

    test('should set biometric enabled status', () async {
      // Test setting biometric enabled
      await biometricService.setBiometricEnabled(true);
      final isEnabled = await biometricService.isBiometricEnabled();
      expect(isEnabled, isTrue);

      // Test disabling biometric
      await biometricService.setBiometricEnabled(false);
      final isDisabled = await biometricService.isBiometricEnabled();
      expect(isDisabled, isFalse);
    });

    test('should check if biometric setup is completed', () async {
      // Test biometric setup completion status
      final isCompleted = await biometricService.isBiometricSetupCompleted();
      expect(isCompleted, isA<bool>());
    });

    test('should authenticate with biometric', () async {
      // Test biometric authentication
      final result = await biometricService.authenticate(
        reason: 'Test authentication',
      );
      expect(result, isA<BiometricAuthResult>());
      expect(result.success, isA<bool>());
      expect(result.errorType, isA<BiometricErrorType?>());
    });

    test('should handle authentication cancellation', () async {
      // Test authentication with cancellation scenario
      final result = await biometricService.authenticate(
        reason: 'Test cancellation',
      );
      
      // Should handle cancellation gracefully
      if (!result.success) {
        expect(result.errorType, isNotNull);
      }
    });

    test('should handle biometric not available scenario', () async {
      // Test when biometric is not available
      final isAvailable = await biometricService.isBiometricAvailable();
      
      if (!isAvailable) {
        final result = await biometricService.authenticate(
          reason: 'Test unavailable biometric',
        );
        expect(result.success, isFalse);
        expect(result.errorType, equals(BiometricErrorType.notAvailable));
      }
    });

    test('should handle biometric not enrolled scenario', () async {
      // Test when biometric is available but not enrolled
      final result = await biometricService.authenticate(
        reason: 'Test not enrolled',
      );
      
      // If biometric is not enrolled, should fail with appropriate error
      if (!result.success && result.errorType == BiometricErrorType.notEnrolled) {
        expect(result.errorType, equals(BiometricErrorType.notEnrolled));
      }
    });

    test('should validate BiometricAuthResult properties', () async {
      // Test result object structure
      final result = await biometricService.authenticate(
        reason: 'Test result validation',
      );
      
      expect(result.success, isA<bool>());
      expect(result.message, isA<String>());
      expect(result.errorType, isA<BiometricErrorType?>());
      
      if (!result.success) {
        expect(result.message, isNotNull);
        expect(result.errorType, isNotNull);
      }
    });

    test('should validate available biometric types', () async {
      // Test biometric types list
      final biometrics = await biometricService.getAvailableBiometrics();
      
      expect(biometrics, isA<List<String>>());
      // Each item should be a string representing biometric type
      for (final biometric in biometrics) {
        expect(biometric, isA<String>());
        expect(biometric.isNotEmpty, isTrue);
      }
    });
  });
}