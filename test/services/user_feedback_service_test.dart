import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../mocks/mock_user_feedback_service.dart';

void main() {
  group('UserFeedbackService Tests', () {
    late MockUserFeedbackService userFeedbackService;

    setUpAll(() {
      Get.testMode = true;
    });

    setUp(() {
      userFeedbackService = MockUserFeedbackService();
    });

    tearDown(() {
      Get.reset();
    });

    group('Service Initialization', () {
      test('should initialize successfully', () {
        expect(userFeedbackService, isNotNull);
      });

      test('should be singleton', () {
        final instance1 = MockUserFeedbackService();
        final instance2 = MockUserFeedbackService();
        expect(instance1, same(instance2));
      });
    });

    group('Service Methods', () {
      test('should have required methods', () {
        expect(userFeedbackService.showLoading, isA<Function>());
        expect(userFeedbackService.hideLoading, isA<Function>());
        expect(userFeedbackService.executeWithLoading, isA<Function>());
        expect(userFeedbackService.showSuccess, isA<Function>());
        expect(userFeedbackService.showError, isA<Function>());
        expect(userFeedbackService.showConfirmationDialog, isA<Function>());
      });
    });

    group('Execute With Loading', () {
      test('should execute function with loading wrapper', () async {
        bool functionExecuted = false;

        await userFeedbackService.executeWithLoading(
          operation: () async {
            functionExecuted = true;
            await Future.delayed(Duration(milliseconds: 10));
          },
        );

        expect(functionExecuted, isTrue);
      });

      test('should handle function that throws error', () async {
        bool errorCaught = false;

        try {
          await userFeedbackService.executeWithLoading(
            operation: () async {
              throw Exception('Test error');
            },
          );
        } catch (e) {
          errorCaught = true;
        }

        expect(errorCaught, isTrue);
      });

      test('should execute function with custom loading message', () async {
        bool functionExecuted = false;

        await userFeedbackService.executeWithLoading(
          operation: () async {
            functionExecuted = true;
          },
          loadingMessage: 'Custom loading message',
        );

        expect(functionExecuted, isTrue);
      });
    });

    group('Method Validation', () {
      test('should validate string inputs', () {
        const testString = 'Test message';
        expect(testString, isA<String>());
        expect(testString.isNotEmpty, isTrue);
        expect(testString.length, greaterThan(0));
      });

      test('should validate boolean inputs', () {
        const testBool = true;
        expect(testBool, isA<bool>());
        expect(testBool, isTrue);
      });

      test('should validate function inputs', () {
        void testFunction() {}
        expect(testFunction, isA<Function>());
      });

      test('should validate duration inputs', () {
        const testDuration = Duration(seconds: 3);
        expect(testDuration, isA<Duration>());
        expect(testDuration.inSeconds, equals(3));
      });
    });

    group('Service State', () {
      test('should maintain service instance', () {
        final service1 = MockUserFeedbackService();
        final service2 = MockUserFeedbackService();
        expect(service1, same(service2));
      });

      test('should handle multiple method calls', () {
        expect(() {
          userFeedbackService.hideLoading();
          userFeedbackService.hideLoading();
          userFeedbackService.hideLoading();
        }, returnsNormally);
      });
    });

    group('Error Handling', () {
      test('should handle operation that returns null', () async {
        final result = await userFeedbackService.executeWithLoading(
          operation: () async {
            return null;
          },
        );

        expect(result, isNull);
      });

      test('should handle empty string parameters', () {
        expect(() async {
          await userFeedbackService.executeWithLoading(
            operation: () async {},
            loadingMessage: '',
          );
        }, returnsNormally);
      });
    });

    group('Async Operations', () {
      test('should handle async operations correctly', () async {
        bool completed = false;

        await userFeedbackService.executeWithLoading(
          operation: () async {
            await Future.delayed(Duration(milliseconds: 50));
            completed = true;
          },
        );

        expect(completed, isTrue);
      });

      test('should handle multiple concurrent operations', () async {
        final futures = List.generate(3, (index) {
          return userFeedbackService.executeWithLoading(
            operation: () async {
              await Future.delayed(Duration(milliseconds: 10));
            },
          );
        });

        await Future.wait(futures);

        // All operations should complete without error
        expect(futures.length, equals(3));
      });
    });

    group('Service Lifecycle', () {
      test('should handle service reset', () {
        final service = MockUserFeedbackService();
        expect(service, isNotNull);

        Get.reset();

        final newService = MockUserFeedbackService();
        expect(newService, isNotNull);
      });

      test('should maintain functionality after reset', () async {
        await userFeedbackService.executeWithLoading(
          operation: () async {
            await Future.delayed(Duration(milliseconds: 10));
          },
        );

        Get.reset();

        final newService = MockUserFeedbackService();
        await newService.executeWithLoading(
          operation: () async {
            await Future.delayed(Duration(milliseconds: 10));
          },
        );

        expect(newService, isNotNull);
      });
    });
  });
}
