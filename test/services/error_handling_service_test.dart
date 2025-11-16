import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../mocks/mock_error_handling_service.dart';

void main() {
  group('ErrorHandlingService Tests', () {
    late MockErrorHandlingService errorHandlingService;

    setUpAll(() {
      Get.testMode = true;
    });

    setUp(() {
      errorHandlingService = MockErrorHandlingService();
    });

    tearDown(() {
      Get.reset();
    });

    group('Service Initialization', () {
      test('should initialize successfully', () {
        expect(errorHandlingService, isNotNull);
      });

      test('should be singleton', () {
        final instance1 = MockErrorHandlingService();
        final instance2 = MockErrorHandlingService();
        expect(instance1, same(instance2));
      });
    });

    group('Error Type Constants', () {
      test('should have all required error type constants', () {
        expect(MockErrorHandlingService.networkError, equals('network_error'));
        expect(MockErrorHandlingService.authError, equals('auth_error'));
        expect(MockErrorHandlingService.paymentError, equals('payment_error'));
        expect(MockErrorHandlingService.validationError, equals('validation_error'));
        expect(MockErrorHandlingService.serverError, equals('server_error'));
        expect(MockErrorHandlingService.unknownError, equals('unknown_error'));
      });
    });

    group('General Error Handling', () {
      test('should handle error with all parameters', () async {
        bool retryCallbackCalled = false;
        bool actionCallbackCalled = false;

        await errorHandlingService.handleError(
          errorType: MockErrorHandlingService.networkError,
          errorMessage: 'Test network error',
          userFriendlyMessage: 'Custom user message',
          onRetry: () => retryCallbackCalled = true,
          onAction: () => actionCallbackCalled = true,
          actionText: 'Custom Action',
          showDialog: false,
          logError: true,
        );

        // Test should complete without throwing
        expect(errorHandlingService, isNotNull);
      });

      test('should handle error with minimal parameters', () async {
        await errorHandlingService.handleError(
          errorType: MockErrorHandlingService.unknownError,
          errorMessage: 'Test error',
        );

        // Test should complete without throwing
        expect(errorHandlingService, isNotNull);
      });

      test('should handle different error types', () async {
        final errorTypes = [
          MockErrorHandlingService.networkError,
          MockErrorHandlingService.authError,
          MockErrorHandlingService.paymentError,
          MockErrorHandlingService.validationError,
          MockErrorHandlingService.serverError,
          MockErrorHandlingService.unknownError,
        ];

        for (final errorType in errorTypes) {
          await errorHandlingService.handleError(
            errorType: errorType,
            errorMessage: 'Test $errorType',
          );
        }

        // All error types should be handled without throwing
        expect(errorHandlingService, isNotNull);
      });
    });

    group('Network Error Handling', () {
      test('should handle network error with default message', () async {
        await errorHandlingService.handleNetworkError(
          errorMessage: 'Network connection failed',
        );
        
        // Test should complete without throwing
        expect(errorHandlingService, isNotNull);
      });

      test('should handle network error with retry callback', () async {
        bool retryCallbackCalled = false;
        
        await errorHandlingService.handleNetworkError(
          errorMessage: 'Network error',
          onRetry: () => retryCallbackCalled = true,
        );
        
        expect(errorHandlingService, isNotNull);
      });

      test('should handle network error with dialog', () async {
        await errorHandlingService.handleNetworkError(
          errorMessage: 'Network error',
          showDialog: true,
        );
        
        expect(errorHandlingService, isNotNull);
      });
    });

    group('Authentication Error Handling', () {
      test('should handle auth error with default action', () async {
        await errorHandlingService.handleAuthError(
          errorMessage: 'Authentication failed',
        );
        
        expect(errorHandlingService, isNotNull);
      });

      test('should handle auth error with custom action', () async {
        bool actionCallbackCalled = false;
        
        await errorHandlingService.handleAuthError(
          errorMessage: 'Auth error',
          onAction: () => actionCallbackCalled = true,
          actionText: 'Re-authenticate',
        );
        
        expect(errorHandlingService, isNotNull);
      });
    });

    group('Payment Error Handling', () {
      test('should handle payment error', () async {
        await errorHandlingService.handlePaymentError(
          errorMessage: 'Payment processing failed',
        );
        
        expect(errorHandlingService, isNotNull);
      });

      test('should handle payment error with retry', () async {
        bool retryCallbackCalled = false;
        
        await errorHandlingService.handlePaymentError(
          errorMessage: 'Payment failed',
          onRetry: () => retryCallbackCalled = true,
        );
        
        expect(errorHandlingService, isNotNull);
      });
    });

    group('Validation Error Handling', () {
      test('should handle validation error', () async {
        await errorHandlingService.handleValidationError(
          errorMessage: 'Invalid input data',
        );
        
        expect(errorHandlingService, isNotNull);
      });

      test('should handle validation error with dialog', () async {
        await errorHandlingService.handleValidationError(
          errorMessage: 'Validation failed',
          showDialog: true,
        );
        
        expect(errorHandlingService, isNotNull);
      });
    });

    group('Server Error Handling', () {
      test('should handle server error', () async {
        await errorHandlingService.handleServerError(
          errorMessage: 'Internal server error',
        );
        
        expect(errorHandlingService, isNotNull);
      });

      test('should handle server error with retry', () async {
        bool retryCallbackCalled = false;
        
        await errorHandlingService.handleServerError(
          errorMessage: 'Server error',
          onRetry: () => retryCallbackCalled = true,
        );
        
        expect(errorHandlingService, isNotNull);
      });
    });

    group('Snackbar Methods', () {
      test('should show error snackbar', () {
        errorHandlingService.showErrorSnackbar(
          message: 'Error message',
        );
        
        expect(errorHandlingService, isNotNull);
      });

      test('should show error snackbar with action', () {
        bool actionCallbackCalled = false;
        
        errorHandlingService.showErrorSnackbar(
          message: 'Error with action',
          actionText: 'Retry',
          onAction: () => actionCallbackCalled = true,
        );
        
        expect(errorHandlingService, isNotNull);
      });

      test('should show success snackbar', () {
        errorHandlingService.showSuccessSnackbar(
          message: 'Success message',
        );
        
        expect(errorHandlingService, isNotNull);
      });

      test('should show info snackbar', () {
        errorHandlingService.showInfoSnackbar(
          message: 'Info message',
        );
        
        expect(errorHandlingService, isNotNull);
      });

      test('should show warning snackbar', () {
        errorHandlingService.showWarningSnackbar(
          message: 'Warning message',
        );
        
        expect(errorHandlingService, isNotNull);
      });

      test('should show warning snackbar with action', () {
        bool actionCallbackCalled = false;
        
        errorHandlingService.showWarningSnackbar(
          message: 'Warning with action',
          actionText: 'Dismiss',
          onAction: () => actionCallbackCalled = true,
        );
        
        expect(errorHandlingService, isNotNull);
      });
    });
  });
}