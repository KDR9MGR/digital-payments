import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import '../utils/app_logger.dart';

/// Debug utility to help manage error states during development
class ErrorDebugHelper {
  static final GetStorage _storage = GetStorage();

  /// Clear all error counts and reset error state
  static void clearAllErrors() {
    try {
      // Clear all error tracking keys
      _storage.remove('subscription_error_count');
      _storage.remove('last_error_time');
      // Critical errors tracking removed
      _storage.remove('network_error_count');
      _storage.remove('payment_error_count');
      _storage.remove('recent_errors');

      AppLogger.log('All error counts cleared successfully');
      if (kDebugMode) print('✅ All error counts have been reset');
    } catch (e) {
      AppLogger.log('Error clearing error counts: $e');
      if (kDebugMode) print('❌ Failed to clear error counts: $e');
    }
  }

  /// Get current error statistics
  static Map<String, dynamic> getErrorStats() {
    // Error statistics method simplified - critical error tracking removed
    final stats = {
      'totalErrors': _storage.read('subscription_error_count') ?? 0,
      'networkErrors': _storage.read('network_error_count') ?? 0,
      'paymentErrors': _storage.read('payment_error_count') ?? 0,
      'lastErrorTime': _storage.read('last_error_time'),
      'recentErrors': _storage.read('recent_errors') ?? [],
    };

    if (kDebugMode) {
    print('📊 Current Error Statistics:');
    print('  Total Errors: ${stats['totalErrors']}');
    print('  Network Errors: ${stats['networkErrors']}');
    print('  Payment Errors: ${stats['paymentErrors']}');
    print('  Last Error Time: ${stats['lastErrorTime']}');
    print('  Recent Errors Count: ${(stats['recentErrors'] as List).length}');
  }

    return stats;
  }

  /// Show recent errors for debugging
  static void showRecentErrors() {
    final recentErrors = _storage.read('recent_errors') ?? [];

    if (kDebugMode) {
       print('🔍 Recent Errors (${recentErrors.length}):');
       for (int i = 0; i < recentErrors.length; i++) {
         final error = recentErrors[i];
         print(
           '  ${i + 1}. [${error['timestamp']}] ${error['type']}: ${error['message']}',
         );
       }
     }
  }
}
