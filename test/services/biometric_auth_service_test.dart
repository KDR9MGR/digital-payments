import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../mocks/mock_biometric_auth_service.dart';
import '../mocks/mock_error_handling_service.dart';

void main() {
  group('BiometricAuthService Tests', () {
    late MockBiometricAuthService biometricAuthService;
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
      biometricAuthService = MockBiometricAuthService();
      errorHandlingService = MockErrorHandlingService();
      
      // Reset mock state
      biometricAuthService.resetMockState();
      
      // Initialize the service
      await biometricAuthService.initialize();
    });

    tearDown(() async {
      // Clean up
      await biometricAuthService.invalidateSession();
      Get.reset();
    });

    group('Service Lifecycle', () {
      test('should create singleton instance', () {
        final instance1 = MockBiometricAuthService();
        final instance2 = MockBiometricAuthService();
        expect(instance1, equals(instance2));
      });

      test('should handle multiple initializations', () async {
        await biometricAuthService.initialize();
        await biometricAuthService.initialize();
        // Should not throw any errors
      });
    });

    group('Biometric Availability', () {
      test('should check if biometric authentication is available', () async {
        final isAvailable = await biometricAuthService.isBiometricAvailable();
        expect(isAvailable, isTrue); // Simulated as true in service
      });

      test('should get available biometric types', () async {
        final availableTypes = await biometricAuthService.getAvailableBiometrics();
        expect(availableTypes, isNotEmpty);
        expect(availableTypes, contains('fingerprint'));
        expect(availableTypes, contains('face'));
      });

      test('should get biometric capability information', () async {
        final capability = await biometricAuthService.getBiometricCapabilities();
        
        expect(capability['isAvailable'], isTrue);
        expect(capability['availableTypes'], isNotEmpty);
        expect(capability['isEnabled'], isFalse); // Default state
        expect(capability['isSetupCompleted'], isFalse); // Default state
      });
    });

    group('Biometric Settings', () {
      test('should return false for biometric enabled when not set', () async {
        final isEnabled = await biometricAuthService.isBiometricEnabled();
        expect(isEnabled, isFalse);
      });

      test('should return false for biometric setup completed when not set', () async {
        final isSetupCompleted = await biometricAuthService.isBiometricSetupCompleted();
        expect(isSetupCompleted, isFalse);
      });

      test('should enable biometric authentication', () async {
        await biometricAuthService.enableBiometric();
        
        expect(await biometricAuthService.isBiometricEnabled(), isTrue);
      });

      test('should disable biometric authentication', () async {
        // First enable it
        await biometricAuthService.enableBiometric();
        
        // Then disable it
        await biometricAuthService.disableBiometric();
        
        expect(await biometricAuthService.isBiometricEnabled(), isFalse);
      });

      test('should mark setup as completed', () async {
        await biometricAuthService.markSetupCompleted();
        
        expect(await biometricAuthService.isBiometricSetupCompleted(), isTrue);
      });
    });

    group('Biometric Authentication', () {
      setUp(() async {
        // Enable biometric authentication for these tests
        await biometricAuthService.enableBiometric();
      });

      test('should authenticate successfully when enabled', () async {
        final result = await biometricAuthService.authenticate(
          reason: 'Test authentication',
        );
        
        expect(result, isTrue);
      });

      test('should fail authentication when biometric is not enabled', () async {
        // Disable biometric first
        await biometricAuthService.disableBiometric();
        
        final result = await biometricAuthService.authenticate(
          reason: 'Test authentication',
        );
        
        expect(result, isFalse);
      });

      test('should handle authentication with reason', () async {
        final result = await biometricAuthService.authenticate(
          reason: 'Secure transaction',
        );
        
        expect(result, isTrue);
      });

      test('should simulate authentication failure', () async {
        final result = await biometricAuthService.simulateAuthentication(
          success: false,
          errorMessage: 'Authentication cancelled',
        );
        
        expect(result, isFalse);
      });

      test('should simulate authentication success', () async {
        final result = await biometricAuthService.simulateAuthentication(
          success: true,
        );
        
        expect(result, isTrue);
      });
    });

    group('Session Management', () {
      test('should return false for session validity when not authenticated', () {
        final isValid = biometricAuthService.isSessionValid();
        expect(isValid, isFalse);
      });

      test('should return true for session validity after authentication', () async {
        await biometricAuthService.enableBiometric();
        await biometricAuthService.authenticate(reason: 'Test');
        
        final isValid = biometricAuthService.isSessionValid();
        expect(isValid, isTrue);
      });

      test('should return null for session time remaining when not authenticated', () {
        final timeRemaining = biometricAuthService.getSessionTimeRemaining();
        expect(timeRemaining, isNull);
      });

      test('should return time remaining after authentication', () async {
        await biometricAuthService.enableBiometric();
        await biometricAuthService.authenticate(reason: 'Test');
        
        final timeRemaining = biometricAuthService.getSessionTimeRemaining();
        expect(timeRemaining, isNotNull);
        expect(timeRemaining!.inMinutes, lessThanOrEqualTo(15));
      });

      test('should invalidate session', () async {
        await biometricAuthService.enableBiometric();
        await biometricAuthService.authenticate(reason: 'Test');
        
        expect(biometricAuthService.isSessionValid(), isTrue);
        
        await biometricAuthService.invalidateSession();
        
        expect(biometricAuthService.isSessionValid(), isFalse);
      });

      test('should handle session timeout', () async {
        await biometricAuthService.enableBiometric();
        
        // Set last auth time to more than 15 minutes ago
        final pastTime = DateTime.now().subtract(Duration(minutes: 16));
        biometricAuthService.setMockLastAuthTime(pastTime);
        
        final isValid = biometricAuthService.isSessionValid();
        expect(isValid, isFalse);
        
        final timeRemaining = biometricAuthService.getSessionTimeRemaining();
        expect(timeRemaining, isNull);
      });
    });

    group('Edge Cases', () {
      test('should handle rapid successive calls', () async {
        await biometricAuthService.enableBiometric();
        
        // Make multiple rapid calls
        final futures = List.generate(5, (index) => 
          biometricAuthService.simulateAuthentication(
            success: false,
            errorMessage: 'Rapid call $index',
          )
        );
        
        final results = await Future.wait(futures);
        
        // All should complete without throwing
        expect(results.length, equals(5));
        expect(results.every((result) => result == false), isTrue);
      });

      test('should handle mock state manipulation', () async {
        // Test direct mock state manipulation
        biometricAuthService.setMockBiometricEnabled(true);
        expect(await biometricAuthService.isBiometricEnabled(), isTrue);
        
        biometricAuthService.setMockSetupCompleted(true);
        expect(await biometricAuthService.isBiometricSetupCompleted(), isTrue);
        
        biometricAuthService.resetMockState();
        expect(await biometricAuthService.isBiometricEnabled(), isFalse);
        expect(await biometricAuthService.isBiometricSetupCompleted(), isFalse);
      });
    });
  });
}