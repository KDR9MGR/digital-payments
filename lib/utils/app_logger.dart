import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  static const String _tag = 'XPay';
  
  static void debug(String message, {String? tag, Object? error}) {
    _log(LogLevel.debug, message, tag: tag, error: error);
  }
  
  static void info(String message, {String? tag}) {
    _log(LogLevel.info, message, tag: tag);
  }
  
  static void warning(String message, {String? tag, Object? error}) {
    _log(LogLevel.warning, message, tag: tag, error: error);
  }
  
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, error: error);
    
    // Report to Crashlytics in production
    if (!kDebugMode && error != null) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: message,
      );
    }
  }
  
  static void _log(LogLevel level, String message, {String? tag, Object? error}) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final logTag = tag ?? _tag;
      final levelStr = level.name.toUpperCase();
      
      debugPrint('[$timestamp] [$levelStr] [$logTag] $message');
      
      if (error != null) {
        debugPrint('[$timestamp] [$levelStr] [$logTag] Error: $error');
      }
    }
  }
  
  // Legacy support for existing print statements
  static void log(String message, {String? tag}) {
    info(message, tag: tag);
  }
}
