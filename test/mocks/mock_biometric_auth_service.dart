import 'package:flutter/material.dart';
import 'package:xpay/utils/app_logger.dart';

/// Mock implementation of BiometricAuthService for testing
class MockBiometricAuthService {
  static final MockBiometricAuthService _instance = MockBiometricAuthService._internal();
  factory MockBiometricAuthService() => _instance;
  MockBiometricAuthService._internal();

  // Mock state
  bool _isInitialized = false;
  bool _biometricEnabled = false;
  bool _setupCompleted = false;
  DateTime? _lastAuthTime;
  static const Duration _sessionTimeout = Duration(minutes: 15);

  /// Initialize the service
  Future<void> initialize() async {
    AppLogger.log('BiometricAuthService initialized');
    _isInitialized = true;
  }

  /// Check if biometric authentication is available on device
  Future<bool> isBiometricAvailable() async {
    AppLogger.log('Biometric availability check (simulated)');
    return true; // Always return true for testing
  }

  /// Get available biometric types
  Future<List<String>> getAvailableBiometrics() async {
    final List<String> availableBiometrics = ['fingerprint', 'face'];
    AppLogger.log('Available biometrics: $availableBiometrics');
    return availableBiometrics;
  }

  /// Check if biometric authentication is enabled by user
  Future<bool> isBiometricEnabled() async {
    return _biometricEnabled;
  }

  /// Check if biometric setup is completed
  Future<bool> isBiometricSetupCompleted() async {
    return _setupCompleted;
  }

  /// Enable biometric authentication
  Future<void> enableBiometric() async {
    AppLogger.log('Biometric authentication enabled');
    _biometricEnabled = true;
  }

  /// Disable biometric authentication
  Future<void> disableBiometric() async {
    AppLogger.log('Biometric authentication disabled');
    _biometricEnabled = false;
  }

  /// Mark biometric setup as completed
  Future<void> markSetupCompleted() async {
    AppLogger.log('Biometric setup marked as completed');
    _setupCompleted = true;
  }

  /// Authenticate using biometrics
  Future<bool> authenticate({String? reason}) async {
    try {
      AppLogger.log('Biometric authentication requested: ${reason ?? "Authentication required"}');
      
      if (!_biometricEnabled) {
        AppLogger.log('Biometric authentication not enabled');
        return false;
      }

      // Simulate successful authentication
      _lastAuthTime = DateTime.now();
      AppLogger.log('Biometric authentication successful');
      return true;
    } catch (e) {
      AppLogger.log('Biometric authentication error: $e');
      return false;
    }
  }

  /// Check if current session is valid
  bool isSessionValid() {
    if (_lastAuthTime == null) return false;
    
    final now = DateTime.now();
    final timeDifference = now.difference(_lastAuthTime!);
    
    return timeDifference < _sessionTimeout;
  }

  /// Get time remaining in current session
  Duration? getSessionTimeRemaining() {
    if (_lastAuthTime == null) return null;
    
    final now = DateTime.now();
    final elapsed = now.difference(_lastAuthTime!);
    final remaining = _sessionTimeout - elapsed;
    
    return remaining.isNegative ? null : remaining;
  }

  /// Invalidate current session
  Future<void> invalidateSession() async {
    AppLogger.log('Biometric session invalidated');
    _lastAuthTime = null;
  }

  /// Get biometric capability information
  Future<Map<String, dynamic>> getBiometricCapabilities() async {
    return {
      'isAvailable': await isBiometricAvailable(),
      'availableTypes': await getAvailableBiometrics(),
      'isEnabled': await isBiometricEnabled(),
      'isSetupCompleted': await isBiometricSetupCompleted(),
    };
  }

  /// Simulate authentication with specific result
  Future<bool> simulateAuthentication({
    required bool success,
    String? errorMessage,
  }) async {
    if (success) {
      _lastAuthTime = DateTime.now();
      AppLogger.log('Simulated biometric authentication successful');
      return true;
    } else {
      final error = errorMessage ?? 'Authentication failed';
      AppLogger.log('Biometric authentication error: $error');
      AppLogger.log('ERROR [auth_error]: $error');
      return false;
    }
  }

  /// Reset mock state for testing
  void resetMockState() {
    _isInitialized = false;
    _biometricEnabled = false;
    _setupCompleted = false;
    _lastAuthTime = null;
  }

  /// Set mock biometric enabled state
  void setMockBiometricEnabled(bool enabled) {
    _biometricEnabled = enabled;
  }

  /// Set mock setup completed state
  void setMockSetupCompleted(bool completed) {
    _setupCompleted = completed;
  }

  /// Set mock last auth time
  void setMockLastAuthTime(DateTime? time) {
    _lastAuthTime = time;
  }
}