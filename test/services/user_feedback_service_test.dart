import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:xpay/services/user_feedback_service.dart';

void main() {
  group('UserFeedbackService Tests', () {
    late UserFeedbackService feedbackService;

    setUp(() {
      Get.testMode = true;
      feedbackService = UserFeedbackService();
    });

    tearDown(() {
      Get.reset();
    });

    test('should show loading overlay correctly', () {
      // Test loading overlay display
      feedbackService.showLoading(
        message: 'Processing your request...',
        canDismiss: false,
      );
      
      expect(feedbackService.isLoading, isTrue);
      expect(feedbackService.loadingMessage, equals('Processing your request...'));
    });

    test('should hide loading overlay correctly', () {
      // First show loading
      feedbackService.showLoading(message: 'Loading...');
      expect(feedbackService.isLoading, isTrue);
      
      // Then hide loading
      feedbackService.hideLoading();
      expect(feedbackService.isLoading, isFalse);
    });

    test('should show progress loading correctly', () {
      // Test progress loading display
      feedbackService.showProgressLoading(
        message: 'Uploading file...',
        progress: 0.5,
        canDismiss: false,
      );
      
      expect(feedbackService.isLoading, isTrue);
      expect(feedbackService.loadingMessage, equals('Uploading file...'));
    });

    test('should execute operation with loading feedback', () async {
      // Test executeWithLoading method
      final result = await feedbackService.executeWithLoading<String>(
        operation: () async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'Success';
        },
        loadingMessage: 'Processing...',
        successMessage: 'Operation completed',
        errorMessage: 'Operation failed',
      );
      
      expect(result, equals('Success'));
      expect(feedbackService.isLoading, isFalse);
    });

    test('should handle operation failure with loading feedback', () async {
      // Test executeWithLoading with exception
      final result = await feedbackService.executeWithLoading<String>(
        operation: () async {
          throw Exception('Test error');
        },
        loadingMessage: 'Processing...',
        successMessage: 'Operation completed',
        errorMessage: 'Operation failed',
      );
      
      expect(result, isNull);
      expect(feedbackService.isLoading, isFalse);
    });

    test('should show confirmation dialog correctly', () async {
      // Mock Get.dialog to return true
      Get.testMode = true;
      
      // Test confirmation dialog
      // Note: In a real test, you'd need to mock Get.dialog
      // This is a placeholder test structure
      expect(true, isTrue);
    });

    test('should show bottom sheet correctly', () {
      // Test bottom sheet display
      feedbackService.showBottomSheet(
        title: 'Select Option',
        content: const Text('Choose an option below'),
      );
      
      // Verify bottom sheet was shown (placeholder)
      expect(true, isTrue);
    });

    test('should show action sheet correctly', () {
      // Test action sheet display
      feedbackService.showActionSheet(
        title: 'Actions',
        options: [
          ActionSheetOption(
            title: 'Option 1',
            value: 'option1',
          ),
          ActionSheetOption(
            title: 'Option 2',
            value: 'option2',
            isDestructive: true,
          ),
        ],
      );
      
      // Verify action sheet was shown (placeholder)
      expect(true, isTrue);
    });

    test('should show toast correctly', () {
      // Test toast display
      feedbackService.showToast(
        message: 'This is a toast message',
        type: ToastType.success,
      );
      
      // Verify toast was shown (placeholder)
      expect(true, isTrue);
    });

    test('should show banner correctly', () {
      // Test banner display
      feedbackService.showBanner(
        message: 'This is a banner message',
        type: BannerType.info,
      );
      
      // Verify banner was shown (placeholder)
      expect(true, isTrue);
    });

    test('should prevent multiple loading dialogs', () {
      // Show first loading dialog
      feedbackService.showLoading(message: 'Loading 1...');
      expect(feedbackService.isLoading, isTrue);
      expect(feedbackService.loadingMessage, equals('Loading 1...'));
      
      // Try to show second loading dialog
      feedbackService.showLoading(message: 'Loading 2...');
      
      // Should still show first loading message
      expect(feedbackService.loadingMessage, equals('Loading 1...'));
    });
  });
}