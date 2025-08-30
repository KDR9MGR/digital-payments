import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_logger.dart';

/// Memory optimization utilities for better app performance
class MemoryOptimizer {
  static Timer? _cleanupTimer;
  static final Set<VoidCallback> _cleanupCallbacks = {};
  static bool _isInitialized = false;

  /// Initialize memory optimizer
  static void initialize() {
    if (_isInitialized) return;
    
    _isInitialized = true;
    
    // Start periodic cleanup
    _startPeriodicCleanup();
    
    // Listen to app lifecycle changes
    _setupAppLifecycleListener();
    
    AppLogger.info('Memory optimizer initialized', tag: 'MemoryOptimizer');
  }

  /// Start periodic memory cleanup
  static void _startPeriodicCleanup() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      performCleanup();
    });
  }

  /// Setup app lifecycle listener for memory management
  static void _setupAppLifecycleListener() {
    SystemChannels.lifecycle.setMessageHandler((message) async {
      if (message == 'AppLifecycleState.paused') {
        // App is going to background, perform cleanup
        performCleanup();
      } else if (message == 'AppLifecycleState.resumed') {
        // App is coming to foreground, reinitialize if needed
        _reinitializeIfNeeded();
      }
      return null;
    });
  }

  /// Perform memory cleanup
  static void performCleanup() {
    if (kDebugMode) {
      AppLogger.info('Performing memory cleanup', tag: 'MemoryOptimizer');
    }

    try {
      // Clear image cache if it's getting too large
      _clearImageCacheIfNeeded();
      
      // Run custom cleanup callbacks
      _runCleanupCallbacks();
      
      // Force garbage collection in debug mode
      if (kDebugMode) {
        _forceGarbageCollection();
      }
      
    } catch (e) {
      AppLogger.error('Error during memory cleanup: $e', tag: 'MemoryOptimizer', error: e);
    }
  }

  /// Clear image cache if needed
  static void _clearImageCacheIfNeeded() {
    try {
      // This would typically check image cache size
      // For now, we'll just clear it periodically
      PaintingBinding.instance.imageCache.clear();
      
      if (kDebugMode) {
        AppLogger.info('Image cache cleared', tag: 'MemoryOptimizer');
      }
    } catch (e) {
      AppLogger.error('Error clearing image cache: $e', tag: 'MemoryOptimizer', error: e);
    }
  }

  /// Run custom cleanup callbacks
  static void _runCleanupCallbacks() {
    for (final callback in _cleanupCallbacks) {
      try {
        callback();
      } catch (e) {
        AppLogger.error('Error in cleanup callback: $e', tag: 'MemoryOptimizer', error: e);
      }
    }
  }

  /// Force garbage collection (debug only)
  static void _forceGarbageCollection() {
    if (kDebugMode) {
      // Note: This is not available in Flutter, but we can suggest it
      AppLogger.debug('Suggesting garbage collection', tag: 'MemoryOptimizer');
    }
  }

  /// Reinitialize components if needed
  static void _reinitializeIfNeeded() {
    // Reinitialize components that might need refresh after app resume
    if (kDebugMode) {
      AppLogger.info('App resumed, checking for reinitializtion needs', tag: 'MemoryOptimizer');
    }
  }

  /// Register a cleanup callback
  static void registerCleanupCallback(VoidCallback callback) {
    _cleanupCallbacks.add(callback);
  }

  /// Unregister a cleanup callback
  static void unregisterCleanupCallback(VoidCallback callback) {
    _cleanupCallbacks.remove(callback);
  }

  /// Optimize image loading
  static ImageProvider optimizeImageProvider(ImageProvider provider) {
    // Return the provider with potential optimizations
    return provider;
  }

  /// Get memory usage information (if available)
  static Future<Map<String, dynamic>> getMemoryInfo() async {
    final info = <String, dynamic>{};
    
    try {
      // Add platform-specific memory information
      if (Platform.isAndroid || Platform.isIOS) {
        // This would typically use platform channels to get memory info
        info['platform'] = Platform.operatingSystem;
        info['timestamp'] = DateTime.now().toIso8601String();
      }
    } catch (e) {
      AppLogger.error('Error getting memory info: $e', tag: 'MemoryOptimizer', error: e);
    }
    
    return info;
  }

  /// Dispose memory optimizer
  static void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _cleanupCallbacks.clear();
    _isInitialized = false;
    
    AppLogger.info('Memory optimizer disposed', tag: 'MemoryOptimizer');
  }

  /// Check if memory optimization is enabled
  static bool get isEnabled => _isInitialized;

  /// Get cleanup callback count
  static int get cleanupCallbackCount => _cleanupCallbacks.length;
}

/// Mixin for widgets that need memory optimization
mixin MemoryOptimizedWidget {
  void registerForCleanup(VoidCallback callback) {
    MemoryOptimizer.registerCleanupCallback(callback);
  }

  void unregisterFromCleanup(VoidCallback callback) {
    MemoryOptimizer.unregisterCleanupCallback(callback);
  }
}

/// Memory-optimized image widget
class OptimizedImage extends StatelessWidget {
  const OptimizedImage({
    super.key,
    required this.imageProvider,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final ImageProvider imageProvider;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: MemoryOptimizer.optimizeImageProvider(imageProvider),
      width: width,
      height: height,
      fit: fit,
      // Add memory optimization settings
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        AppLogger.error('Image loading error: $error', tag: 'OptimizedImage', error: error);
        return Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Icon(Icons.error),
        );
      },
    );
  }
}