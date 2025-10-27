import 'package:flutter/foundation.dart';

/// Performance configuration and optimization utilities
class PerformanceConfig {
  // Private constructor to prevent instantiation
  PerformanceConfig._();

  /// Enable performance overlay in debug mode
  static const bool showPerformanceOverlay = kDebugMode && false;

  /// Enable repaint rainbow in debug mode
  static const bool showRepaintRainbow = kDebugMode && false;

  /// Enable semantics debugger in debug mode
  static const bool showSemanticsDebugger = kDebugMode && false;

  /// Maximum number of cached images
  static const int maxImageCacheSize = 100;

  /// Maximum image cache memory in MB
  static const int maxImageCacheMemory = 50;

  /// Enable image caching
  static const bool enableImageCaching = true;

  /// Animation duration for better performance
  static const Duration fastAnimationDuration = Duration(milliseconds: 200);
  static const Duration normalAnimationDuration = Duration(milliseconds: 300);
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);

  /// Debounce duration for user inputs
  static const Duration debounceDuration = Duration(milliseconds: 300);

  /// Network timeout configurations
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration shortNetworkTimeout = Duration(seconds: 10);

  /// List view performance settings
  static const double listViewCacheExtent = 200.0;
  static const int maxListViewItems = 50;

  /// Memory management settings
  static const bool enableMemoryOptimization = true;
  static const Duration memoryCleanupInterval = Duration(minutes: 5);

  /// Firebase performance settings
  static const bool enableFirebasePerformance = !kDebugMode;
  static const bool enableCrashlytics = !kDebugMode;

  /// Build optimization flags
  static const bool enableTreeShaking = true;
  static const bool enableMinification = !kDebugMode;
  static const bool enableObfuscation = !kDebugMode;

  /// Widget optimization settings
  static const bool useConstConstructors = true;
  static const bool enableWidgetInspector = kDebugMode;

  /// Platform-specific optimizations
  static bool get isHighPerformanceDevice {
    // This would typically check device specs
    // For now, assume all devices are capable
    return true;
  }

  /// Get recommended frame rate based on device capability
  static int get recommendedFrameRate {
    return isHighPerformanceDevice ? 60 : 30;
  }

  /// Check if device supports advanced graphics features
  static bool get supportsAdvancedGraphics {
    return isHighPerformanceDevice;
  }
}

/// Performance monitoring utilities
class PerformanceMonitor {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, List<Duration>> _measurements = {};

  /// Start measuring performance for a specific operation
  static void startMeasurement(String operation) {
    if (kDebugMode) {
      _startTimes[operation] = DateTime.now();
    }
  }

  /// End measurement and log the duration
  static void endMeasurement(String operation) {
    if (kDebugMode && _startTimes.containsKey(operation)) {
      final duration = DateTime.now().difference(_startTimes[operation]!);
      _measurements.putIfAbsent(operation, () => []).add(duration);
      
      debugPrint('⏱️ Performance: $operation took ${duration.inMilliseconds}ms');
      
      // Warn if operation takes too long
      if (duration.inMilliseconds > 100) {
        debugPrint('⚠️ Performance Warning: $operation is slow (${duration.inMilliseconds}ms)');
      }
      
      _startTimes.remove(operation);
    }
  }

  /// Get average duration for an operation
  static Duration? getAverageDuration(String operation) {
    if (!_measurements.containsKey(operation) || _measurements[operation]!.isEmpty) {
      return null;
    }
    
    final measurements = _measurements[operation]!;
    final totalMs = measurements.fold<int>(0, (sum, duration) => sum + duration.inMilliseconds);
    return Duration(milliseconds: totalMs ~/ measurements.length);
  }

  /// Clear all measurements
  static void clearMeasurements() {
    _startTimes.clear();
    _measurements.clear();
  }

  /// Print performance summary
  static void printSummary() {
    if (kDebugMode && _measurements.isNotEmpty) {
      debugPrint('📊 Performance Summary:');
      _measurements.forEach((operation, durations) {
        final avg = getAverageDuration(operation);
        debugPrint('  $operation: ${durations.length} calls, avg: ${avg?.inMilliseconds}ms');
      });
    }
  }
}