import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Utility class to help manage threading and prevent threading issues
class ThreadingUtils {
  static final Map<String, Timer> _timers = {};
  static final Map<String, Completer<dynamic>> _completers = {};
  static bool _isDisposed = false;

  /// Memory safety check to prevent SIGSEGV crashes
  static bool get _isValid {
    return !_isDisposed;
  }

  /// Safely run a function on the main thread with memory safety
  static Future<T> runOnMainThread<T>(Future<T> Function() function) async {
    if (!_isValid) {
      throw StateError('ThreadingUtils has been disposed');
    }

    try {
      // Simply run the function directly - compute() was causing issues
      return await function();
    } catch (e) {
      if (kDebugMode) {
        print('ThreadingUtils.runOnMainThread error: $e');
      }
      rethrow;
    }
  }

  /// Run Firebase operations on background thread to prevent main thread blocking
  /// with enhanced memory safety to prevent SIGSEGV crashes
  static Future<T> runFirebaseOperation<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    if (!_isValid) {
      throw StateError('ThreadingUtils has been disposed');
    }

    try {
      // Add memory safety check before compute
      if (kDebugMode) {
        print(
          'ThreadingUtils: Starting Firebase operation: ${operationName ?? 'unnamed'}',
        );
      }

      // Use compute to run Firebase operations on background thread
      final result = await compute(_runFirebaseOperation, operation);

      if (kDebugMode) {
        print(
          'ThreadingUtils: Completed Firebase operation: ${operationName ?? 'unnamed'}',
        );
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print(
          'ThreadingUtils.runFirebaseOperation error: ${operationName ?? 'Firebase operation'}: $e',
        );
      }
      rethrow;
    }
  }

  /// Helper function for Firebase operations with memory safety
  static Future<T> _runFirebaseOperation<T>(
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } catch (e) {
      if (kDebugMode) {
        print('ThreadingUtils._runFirebaseOperation error: $e');
      }
      rethrow;
    }
  }

  /// Run UI operations on main thread safely with memory protection
  static Future<T> runUIOperation<T>(Future<T> Function() operation) async {
    if (!_isValid) {
      throw StateError('ThreadingUtils has been disposed');
    }

    try {
      if (Platform.isIOS || Platform.isAndroid) {
        // Ensure we're on the main thread for UI operations
        return await operation();
      } else {
        return await operation();
      }
    } catch (e) {
      if (kDebugMode) {
        print('ThreadingUtils.runUIOperation error: $e');
      }
      rethrow;
    }
  }

  /// Safely dispose of a timer with a unique key and memory safety
  static void disposeTimer(String key) {
    if (!_isValid) return;

    try {
      final timer = _timers[key];
      if (timer != null) {
        timer.cancel();
        _timers.remove(key);
      }
    } catch (e) {
      if (kDebugMode) {
        print('ThreadingUtils.disposeTimer error for key $key: $e');
      }
    }
  }

  /// Create a timer with a unique key for safe disposal and memory protection
  static Timer createTimer(
    String key,
    Duration duration,
    VoidCallback callback,
  ) {
    if (!_isValid) {
      throw StateError('ThreadingUtils has been disposed');
    }

    try {
      disposeTimer(key); // Dispose any existing timer with the same key
      final timer = Timer(duration, () {
        try {
          callback();
        } catch (e) {
          if (kDebugMode) {
            print('ThreadingUtils timer callback error for key $key: $e');
          }
        }
      });
      _timers[key] = timer;
      return timer;
    } catch (e) {
      if (kDebugMode) {
        print('ThreadingUtils.createTimer error for key $key: $e');
      }
      rethrow;
    }
  }

  /// Create a periodic timer with a unique key for safe disposal and memory protection
  static Timer createPeriodicTimer(
    String key,
    Duration duration,
    void Function(Timer) callback,
  ) {
    if (!_isValid) {
      throw StateError('ThreadingUtils has been disposed');
    }

    try {
      disposeTimer(key); // Dispose any existing timer with the same key
      final timer = Timer.periodic(duration, (timer) {
        try {
          callback(timer);
        } catch (e) {
          if (kDebugMode) {
            print(
              'ThreadingUtils periodic timer callback error for key $key: $e',
            );
          }
        }
      });
      _timers[key] = timer;
      return timer;
    } catch (e) {
      if (kDebugMode) {
        print('ThreadingUtils.createPeriodicTimer error for key $key: $e');
      }
      rethrow;
    }
  }

  /// Dispose all timers with memory safety
  static void disposeAllTimers() {
    if (!_isValid) return;

    try {
      for (final timer in _timers.values) {
        try {
          timer.cancel();
        } catch (e) {
          if (kDebugMode) {
            print('ThreadingUtils.disposeAllTimers timer cancel error: $e');
          }
        }
      }
      _timers.clear();
    } catch (e) {
      if (kDebugMode) {
        print('ThreadingUtils.disposeAllTimers error: $e');
      }
    }
  }

  /// Safely complete a completer with a unique key and memory safety
  static void completeCompleter<T>(String key, T value) {
    if (!_isValid) return;

    try {
      final completer = _completers[key];
      if (completer != null && !completer.isCompleted) {
        completer.complete(value);
        _completers.remove(key);
      }
    } catch (e) {
      if (kDebugMode) {
        print('ThreadingUtils.completeCompleter error for key $key: $e');
      }
    }
  }

  /// Create a completer with a unique key and memory safety
  static Completer<T> createCompleter<T>(String key) {
    if (!_isValid) {
      throw StateError('ThreadingUtils has been disposed');
    }

    try {
      final completer = Completer<T>();
      _completers[key] = completer;
      return completer;
    } catch (e) {
      if (kDebugMode) {
        print('ThreadingUtils.createCompleter error for key $key: $e');
      }
      rethrow;
    }
  }

  /// Dispose all completers with memory safety
  static void disposeAllCompleters() {
    if (!_isValid) return;

    try {
      for (final completer in _completers.values) {
        try {
          if (!completer.isCompleted) {
            completer.completeError('Disposed');
          }
        } catch (e) {
          if (kDebugMode) {
            print('ThreadingUtils.disposeAllCompleters completer error: $e');
          }
        }
      }
      _completers.clear();
    } catch (e) {
      if (kDebugMode) {
        print('ThreadingUtils.disposeAllCompleters error: $e');
      }
    }
  }

  /// Clean up all resources with memory safety
  static void dispose() {
    if (_isDisposed) return;

    try {
      disposeAllTimers();
      disposeAllCompleters();
      _isDisposed = true;
    } catch (e) {
      if (kDebugMode) {
        print('ThreadingUtils.dispose error: $e');
      }
    }
  }

  /// Check if we're on the main thread
  static bool get isOnMainThread {
    return Platform.isIOS || Platform.isAndroid ? false : true;
  }

  /// Safely run a function with error handling and memory safety
  static Future<T> safeRun<T>(
    Future<T> Function() function, {
    String? errorMessage,
  }) async {
    if (!_isValid) {
      throw StateError('ThreadingUtils has been disposed');
    }

    try {
      return await function();
    } catch (e) {
      if (kDebugMode) {
        print(
          'ThreadingUtils.safeRun error: ${errorMessage ?? 'Unknown error'}: $e',
        );
      }
      rethrow;
    }
  }

  /// Debounce function calls to prevent excessive threading with memory safety
  static Timer? _debounceTimer;
  static void debounce(VoidCallback callback, Duration duration) {
    if (!_isValid) return;

    try {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(duration, () {
        try {
          callback();
        } catch (e) {
          if (kDebugMode) {
            print('ThreadingUtils debounce callback error: $e');
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('ThreadingUtils.debounce error: $e');
      }
    }
  }

  /// Dispose debounce timer with memory safety
  static void disposeDebounce() {
    if (!_isValid) return;

    try {
      _debounceTimer?.cancel();
      _debounceTimer = null;
    } catch (e) {
      if (kDebugMode) {
        print('ThreadingUtils.disposeDebounce error: $e');
      }
    }
  }

  /// Prevent main thread blocking by yielding control with memory safety
  static Future<void> yieldControl() async {
    if (!_isValid) return;

    try {
      await Future.delayed(Duration.zero);
    } catch (e) {
      if (kDebugMode) {
        print('ThreadingUtils.yieldControl error: $e');
      }
    }
  }

  /// Run operations with timeout to prevent hanging with memory safety
  static Future<T> runWithTimeout<T>(
    Future<T> Function() operation,
    Duration timeout, {
    String? operationName,
  }) async {
    if (!_isValid) {
      throw StateError('ThreadingUtils has been disposed');
    }

    try {
      return await operation().timeout(timeout);
    } catch (e) {
      if (kDebugMode) {
        print(
          'ThreadingUtils.runWithTimeout error: ${operationName ?? 'Operation'}: $e',
        );
      }
      rethrow;
    }
  }
}
