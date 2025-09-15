import 'package:flutter/material.dart';
import 'package:xpay/utils/app_logger.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Mock implementation of PinAuthService for testing
class MockPinAuthService {
  static final MockPinAuthService _instance = MockPinAuthService._internal();
  factory MockPinAuthService() => _instance;
  MockPinAuthService._internal();

  // Mock state
  bool _isInitialized = false;
  bool _pinEnabled = false;
  bool _setupCompleted = false;
  String? _pinHash;
  String? _pinSalt;
  DateTime? _lastAuthTime;
  int _failedAttempts = 0;
  DateTime? _lockoutTime;
  
  // Security settings
  static const int _maxFailedAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 15);
  static const Duration _sessionTimeout = Duration(minutes: 10);

  /// Initialize the service
  Future<void> initialize() async {
    AppLogger.log('PinAuthService initialized');
    _isInitialized = true;
  }

  /// Check if PIN is enabled
  Future<bool> isPinEnabled() async {
    return _pinEnabled;
  }

  /// Check if PIN setup is completed
  Future<bool> isPinSetupCompleted() async {
    return _setupCompleted;
  }

  /// Check if account is locked out
  Future<bool> isLockedOut() async {
    if (_lockoutTime == null) return false;
    
    final now = DateTime.now();
    final timeDifference = now.difference(_lockoutTime!);
    
    if (timeDifference >= _lockoutDuration) {
      // Lockout period has expired
      _lockoutTime = null;
      _failedAttempts = 0;
      return false;
    }
    
    return true;
  }

  /// Get remaining lockout time
  Future<Duration?> getRemainingLockoutTime() async {
    if (_lockoutTime == null) return null;
    
    final now = DateTime.now();
    final elapsed = now.difference(_lockoutTime!);
    final remaining = _lockoutDuration - elapsed;
    
    return remaining.isNegative ? null : remaining;
  }

  /// Set up a new PIN
  Future<Map<String, dynamic>> setupPin(String pin) async {
    try {
      // Validate PIN
      final validation = _validatePin(pin);
      if (!validation['isValid']) {
        return {
          'success': false,
          'message': validation['message'],
          'errorType': 'validation_error',
        };
      }

      // Generate salt and hash
      final salt = _generateSalt();
      final hash = _hashPin(pin, salt);
      
      // Store PIN data
      _pinHash = hash;
      _pinSalt = salt;
      _pinEnabled = true;
      _setupCompleted = true;
      
      AppLogger.log('PIN setup completed successfully');
      
      return {
        'success': true,
        'message': 'PIN setup completed successfully',
      };
    } catch (e) {
      AppLogger.log('Error setting up PIN: $e');
      return {
        'success': false,
        'message': 'Failed to setup PIN',
        'errorType': 'setup_error',
      };
    }
  }

  /// Authenticate with PIN
  Future<Map<String, dynamic>> authenticate(String pin, {bool sensitiveTransaction = false}) async {
    try {
      // Check if locked out
      if (await isLockedOut()) {
        final remaining = await getRemainingLockoutTime();
        return {
          'success': false,
          'message': 'Account locked. Try again in ${remaining?.inMinutes ?? 0} minutes',
          'errorType': 'locked_out',
        };
      }

      // Check if PIN is enabled
      if (!_pinEnabled || !_setupCompleted) {
        return {
          'success': false,
          'message': 'PIN not enabled or setup not completed',
          'errorType': 'not_enabled',
        };
      }

      // For non-sensitive transactions, check if session is still valid
      if (!sensitiveTransaction && isSessionValid()) {
        AppLogger.log('Using cached PIN authentication');
        return {
          'success': true,
          'message': 'Authentication successful (cached)',
        };
      }

      // Verify PIN
      final isValid = _verifyPin(pin);
      
      if (isValid) {
        _lastAuthTime = DateTime.now();
        _failedAttempts = 0;
        _lockoutTime = null;
        
        AppLogger.log('PIN authentication successful');
        
        return {
          'success': true,
          'message': 'Authentication successful',
        };
      } else {
        _failedAttempts++;
        
        if (_failedAttempts >= _maxFailedAttempts) {
          _lockoutTime = DateTime.now();
          AppLogger.log('Account locked due to too many failed attempts');
          
          return {
            'success': false,
            'message': 'Too many failed attempts. Account locked for ${_lockoutDuration.inMinutes} minutes',
            'errorType': 'locked_out',
          };
        }
        
        final remainingAttempts = _maxFailedAttempts - _failedAttempts;
        return {
          'success': false,
          'message': 'Incorrect PIN. $remainingAttempts attempts remaining',
          'errorType': 'incorrect_pin',
          'remainingAttempts': remainingAttempts,
        };
      }
    } catch (e) {
      AppLogger.log('Error during PIN authentication: $e');
      return {
        'success': false,
        'message': 'Authentication failed',
        'errorType': 'auth_error',
      };
    }
  }

  /// Change PIN
  Future<Map<String, dynamic>> changePin(String currentPin, String newPin) async {
    try {
      // Verify current PIN
      if (!_verifyPin(currentPin)) {
        return {
          'success': false,
          'message': 'Current PIN is incorrect',
          'errorType': 'incorrect_current_pin',
        };
      }

      // Check if new PIN is same as current
      if (currentPin == newPin) {
        return {
          'success': false,
          'message': 'New PIN must be different from current PIN',
          'errorType': 'same_pin',
        };
      }

      // Validate new PIN
      final validation = _validatePin(newPin);
      if (!validation['isValid']) {
        return {
          'success': false,
          'message': validation['message'],
          'errorType': 'validation_error',
        };
      }

      // Generate new salt and hash
      final salt = _generateSalt();
      final hash = _hashPin(newPin, salt);
      
      // Update PIN data
      _pinHash = hash;
      _pinSalt = salt;
      
      AppLogger.log('PIN changed successfully');
      
      return {
        'success': true,
        'message': 'PIN changed successfully',
      };
    } catch (e) {
      AppLogger.log('Error changing PIN: $e');
      return {
        'success': false,
        'message': 'Failed to change PIN',
        'errorType': 'change_error',
      };
    }
  }

  /// Disable PIN authentication
  Future<Map<String, dynamic>> disablePin(String currentPin) async {
    try {
      // Verify current PIN
      if (!_verifyPin(currentPin)) {
        return {
          'success': false,
          'message': 'Current PIN is incorrect',
          'errorType': 'incorrect_pin',
        };
      }

      // Disable PIN
      _pinEnabled = false;
      _setupCompleted = false;
      _pinHash = null;
      _pinSalt = null;
      _lastAuthTime = null;
      _failedAttempts = 0;
      _lockoutTime = null;
      
      AppLogger.log('PIN authentication disabled');
      
      return {
        'success': true,
        'message': 'PIN authentication disabled',
      };
    } catch (e) {
      AppLogger.log('Error disabling PIN: $e');
      return {
        'success': false,
        'message': 'Failed to disable PIN',
        'errorType': 'disable_error',
      };
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
    AppLogger.log('PIN session invalidated');
    _lastAuthTime = null;
  }

  /// Quick authentication (uses cached session if valid)
  Future<bool> quickAuthenticate() async {
    return isSessionValid();
  }

  /// Secure authentication (always requires PIN input)
  Future<Map<String, dynamic>> secureAuthenticate(String pin, {required String operation}) async {
    AppLogger.log('Secure PIN authentication for: $operation');
    return await authenticate(pin, sensitiveTransaction: true);
  }

  /// Validate PIN format and strength
  Map<String, dynamic> _validatePin(String pin) {
    if (pin.length < 4) {
      return {
        'isValid': false,
        'message': 'PIN must be at least 4 digits',
      };
    }
    
    if (pin.length > 8) {
      return {
        'isValid': false,
        'message': 'PIN must be at most 8 digits',
      };
    }
    
    if (!RegExp(r'^[0-9]+$').hasMatch(pin)) {
      return {
        'isValid': false,
        'message': 'PIN must contain only numbers',
      };
    }
    
    // Check for weak patterns
    if (_isWeakPin(pin)) {
      return {
        'isValid': false,
        'message': 'PIN is too weak. Avoid sequential or repeated numbers',
      };
    }
    
    return {
      'isValid': true,
      'message': 'PIN is valid',
    };
  }

  /// Check if PIN is weak (sequential or repeated)
  bool _isWeakPin(String pin) {
    // Check for repeated digits (all same)
    if (RegExp(r'^(.)\1+\$').hasMatch(pin)) {
      return true;
    }
    
    // Check for simple sequential patterns
    if (pin == '1234' || pin == '4321' || pin == '0000' || pin == '1111') {
      return true;
    }
    
    return false;
  }

  /// Generate random salt
  String _generateSalt() {
    final bytes = List<int>.generate(32, (i) => DateTime.now().millisecondsSinceEpoch % 256);
    return base64.encode(bytes);
  }

  /// Hash PIN with salt
  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode(pin + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify PIN against stored hash
  bool _verifyPin(String pin) {
    if (_pinHash == null || _pinSalt == null) return false;
    
    final hash = _hashPin(pin, _pinSalt!);
    return hash == _pinHash;
  }

  /// Reset mock state for testing
  void resetMockState() {
    _isInitialized = false;
    _pinEnabled = false;
    _setupCompleted = false;
    _pinHash = null;
    _pinSalt = null;
    _lastAuthTime = null;
    _failedAttempts = 0;
    _lockoutTime = null;
  }

  /// Set mock PIN enabled state
  void setMockPinEnabled(bool enabled) {
    _pinEnabled = enabled;
  }

  /// Set mock setup completed state
  void setMockSetupCompleted(bool completed) {
    _setupCompleted = completed;
  }

  /// Set mock failed attempts
  void setMockFailedAttempts(int attempts) {
    _failedAttempts = attempts;
  }

  /// Set mock lockout time
  void setMockLockoutTime(DateTime? time) {
    _lockoutTime = time;
  }

  /// Set mock last auth time
  void setMockLastAuthTime(DateTime? time) {
    _lastAuthTime = time;
  }

  /// Setup mock PIN for testing
  void setupMockPin(String pin) {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    _pinHash = hash;
    _pinSalt = salt;
    _pinEnabled = true;
    _setupCompleted = true;
  }
}