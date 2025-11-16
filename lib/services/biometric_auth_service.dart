import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xpay/utils/app_logger.dart';
import 'package:xpay/services/error_handling_service.dart';
import 'package:get/get.dart';

/// Comprehensive biometric authentication service
class BiometricAuthService {
  static final BiometricAuthService _instance = BiometricAuthService._internal();
  factory BiometricAuthService() => _instance;
  BiometricAuthService._internal();

  final ErrorHandlingService _errorHandler = ErrorHandlingService();
  
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricSetupKey = 'biometric_setup_completed';
  static const String _lastAuthTimeKey = 'last_biometric_auth_time';
  
  // Session management
  DateTime? _lastAuthTime;
  static const Duration _sessionTimeout = Duration(minutes: 15);

  /// Check if biometric authentication is available on device
  Future<bool> isBiometricAvailable() async {
    try {
      // For now, we'll simulate biometric availability
      // In a real implementation, you would add local_auth package
      AppLogger.log('Biometric availability check (simulated)');
      return true; // Simulate availability for demo
    } catch (e) {
      AppLogger.log('Error checking biometric availability: $e');
      return false;
    }
  }

  /// Get available biometric types
  Future<List<String>> getAvailableBiometrics() async {
    try {
      // Simulate available biometric types
      final List<String> availableBiometrics = ['fingerprint', 'face'];
      AppLogger.log('Available biometrics: $availableBiometrics');
      return availableBiometrics;
    } catch (e) {
      AppLogger.log('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Check if biometric authentication is enabled by user
  Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricEnabledKey) ?? false;
    } catch (e) {
      AppLogger.log('Error checking biometric enabled status: $e');
      return false;
    }
  }

  /// Enable or disable biometric authentication
  Future<bool> setBiometricEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, enabled);
      
      if (enabled) {
        await prefs.setBool(_biometricSetupKey, true);
      }
      
      AppLogger.log('Biometric authentication ${enabled ? 'enabled' : 'disabled'}');
      return true;
    } catch (e) {
      AppLogger.log('Error setting biometric enabled status: $e');
      await _errorHandler.handleError(
        errorType: ErrorHandlingService.unknownError,
        errorMessage: e.toString(),
        userFriendlyMessage: 'Failed to update biometric settings',
      );
      return false;
    }
  }

  /// Check if biometric setup is completed
  Future<bool> isBiometricSetupCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricSetupKey) ?? false;
    } catch (e) {
      AppLogger.log('Error checking biometric setup status: $e');
      return false;
    }
  }

  /// Authenticate using biometrics
  Future<BiometricAuthResult> authenticate({
    required String reason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
    bool sensitiveTransaction = false,
  }) async {
    try {
      // Check if biometric is available
      if (!await isBiometricAvailable()) {
        return BiometricAuthResult(
          success: false,
          errorType: BiometricErrorType.notAvailable,
          message: 'Biometric authentication is not available on this device',
        );
      }

      // Check if biometric is enabled
      if (!await isBiometricEnabled()) {
        return BiometricAuthResult(
          success: false,
          errorType: BiometricErrorType.notEnabled,
          message: 'Biometric authentication is not enabled',
        );
      }

      // Check session timeout for sensitive transactions
      if (sensitiveTransaction && !_isSessionValid()) {
        // Force fresh authentication for sensitive operations
        _lastAuthTime = null;
      } else if (_isSessionValid() && !sensitiveTransaction) {
        // Use cached authentication for non-sensitive operations
        return BiometricAuthResult(
          success: true,
          message: 'Authentication successful (cached)',
        );
      }

      // Simulate biometric authentication with dialog
      final bool didAuthenticate = await _showBiometricDialog(reason);

      if (didAuthenticate) {
        _lastAuthTime = DateTime.now();
        await _updateLastAuthTime();
        
        AppLogger.log('Biometric authentication successful');
        return BiometricAuthResult(
          success: true,
          message: 'Authentication successful',
        );
      } else {
        AppLogger.log('Biometric authentication failed or cancelled');
        return BiometricAuthResult(
          success: false,
          errorType: BiometricErrorType.authenticationFailed,
          message: 'Authentication failed or was cancelled',
        );
      }
    } catch (e) {
      AppLogger.log('Biometric authentication error: $e');
      
      BiometricErrorType errorType;
      String message;
      
      if (e.toString().contains('NotAvailable')) {
        errorType = BiometricErrorType.notAvailable;
        message = 'Biometric authentication is not available';
      } else if (e.toString().contains('NotEnrolled')) {
        errorType = BiometricErrorType.notEnrolled;
        message = 'No biometric credentials are enrolled on this device';
      } else if (e.toString().contains('LockedOut')) {
        errorType = BiometricErrorType.lockedOut;
        message = 'Biometric authentication is temporarily locked. Please try again later';
      } else if (e.toString().contains('PermanentlyLockedOut')) {
        errorType = BiometricErrorType.permanentlyLockedOut;
        message = 'Biometric authentication is permanently locked. Please use device credentials';
      } else {
        errorType = BiometricErrorType.unknown;
        message = 'An unexpected error occurred during authentication';
      }
      
      await _errorHandler.handleError(
        errorType: ErrorHandlingService.authError,
        errorMessage: e.toString(),
        userFriendlyMessage: message,
      );
      
      return BiometricAuthResult(
        success: false,
        errorType: errorType,
        message: message,
      );
    }
  }

  /// Quick authentication for app unlock
  Future<bool> quickAuthenticate() async {
    final result = await authenticate(
      reason: 'Please authenticate to access your account',
      sensitiveTransaction: false,
    );
    return result.success;
  }

  /// Secure authentication for sensitive operations
  Future<bool> secureAuthenticate({
    required String operation,
  }) async {
    final result = await authenticate(
      reason: 'Please authenticate to $operation',
      sensitiveTransaction: true,
      stickyAuth: true,
    );
    return result.success;
  }

  /// Check if current session is valid
  bool _isSessionValid() {
    if (_lastAuthTime == null) return false;
    
    final now = DateTime.now();
    final timeDifference = now.difference(_lastAuthTime!);
    
    return timeDifference < _sessionTimeout;
  }

  /// Update last authentication time in storage
  Future<void> _updateLastAuthTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastAuthTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      AppLogger.log('Error updating last auth time: $e');
    }
  }

  /// Load last authentication time from storage
  Future<void> _loadLastAuthTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastAuthTimeKey);
      if (timestamp != null) {
        _lastAuthTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      AppLogger.log('Error loading last auth time: $e');
    }
  }

  /// Invalidate current session
  Future<void> invalidateSession() async {
    _lastAuthTime = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastAuthTimeKey);
      AppLogger.log('Biometric session invalidated');
    } catch (e) {
      AppLogger.log('Error invalidating session: $e');
    }
  }

  /// Initialize service
  Future<void> initialize() async {
    await _loadLastAuthTime();
    AppLogger.log('BiometricAuthService initialized');
  }

  /// Show biometric authentication dialog (simulation)
  Future<bool> _showBiometricDialog(String reason) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.fingerprint, color: Colors.blue),
            SizedBox(width: 8),
            Text('Biometric Authentication'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(reason),
            const SizedBox(height: 16),
            const Icon(
              Icons.fingerprint,
              size: 64,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            const Text(
              'Touch the fingerprint sensor',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Simulate Success'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Get biometric capability info
  Future<BiometricCapability> getBiometricCapability() async {
    final isAvailable = await isBiometricAvailable();
    final availableTypes = await getAvailableBiometrics();
    final isEnabled = await isBiometricEnabled();
    final isSetupCompleted = await isBiometricSetupCompleted();
    
    return BiometricCapability(
      isAvailable: isAvailable,
      availableTypes: availableTypes,
      isEnabled: isEnabled,
      isSetupCompleted: isSetupCompleted,
    );
  }
}

/// Biometric authentication result
class BiometricAuthResult {
  final bool success;
  final BiometricErrorType? errorType;
  final String message;
  
  const BiometricAuthResult({
    required this.success,
    this.errorType,
    required this.message,
  });
}

/// Biometric error types
enum BiometricErrorType {
  notAvailable,
  notEnabled,
  notEnrolled,
  authenticationFailed,
  lockedOut,
  permanentlyLockedOut,
  unknown,
}

/// Biometric capability information
class BiometricCapability {
  final bool isAvailable;
  final List<String> availableTypes;
  final bool isEnabled;
  final bool isSetupCompleted;
  
  const BiometricCapability({
    required this.isAvailable,
    required this.availableTypes,
    required this.isEnabled,
    required this.isSetupCompleted,
  });
  
  bool get hasFaceID => availableTypes.contains('face');
  bool get hasFingerprint => availableTypes.contains('fingerprint');
  bool get hasIris => availableTypes.contains('iris');
  
  String get primaryBiometricName {
    if (hasFaceID) return 'Face ID';
    if (hasFingerprint) return 'Fingerprint';
    if (hasIris) return 'Iris';
    return 'Biometric';
  }
}