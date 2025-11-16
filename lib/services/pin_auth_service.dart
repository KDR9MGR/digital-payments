import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:xpay/utils/app_logger.dart';
import 'package:xpay/services/error_handling_service.dart';
import 'package:xpay/utils/custom_color.dart';
import 'package:xpay/utils/custom_style.dart';

/// Comprehensive PIN authentication service
class PinAuthService {
  static final PinAuthService _instance = PinAuthService._internal();
  factory PinAuthService() => _instance;
  PinAuthService._internal();

  final ErrorHandlingService _errorHandler = ErrorHandlingService();
  
  static const String _pinHashKey = 'user_pin_hash';
  static const String _pinSaltKey = 'user_pin_salt';
  static const String _pinEnabledKey = 'pin_enabled';
  static const String _pinSetupKey = 'pin_setup_completed';
  static const String _lastPinAuthKey = 'last_pin_auth_time';
  static const String _failedAttemptsKey = 'pin_failed_attempts';
  static const String _lockoutTimeKey = 'pin_lockout_time';
  
  // Security settings
  static const int _maxFailedAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 15);
  static const Duration _sessionTimeout = Duration(minutes: 10);
  
  // Session management
  DateTime? _lastAuthTime;
  int _failedAttempts = 0;
  DateTime? _lockoutTime;

  /// Check if PIN is enabled
  Future<bool> isPinEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_pinEnabledKey) ?? false;
    } catch (e) {
      AppLogger.log('Error checking PIN enabled status: $e');
      return false;
    }
  }

  /// Check if PIN setup is completed
  Future<bool> isPinSetupCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_pinSetupKey) ?? false;
    } catch (e) {
      AppLogger.log('Error checking PIN setup status: $e');
      return false;
    }
  }

  /// Check if account is currently locked out
  Future<bool> isLockedOut() async {
    await _loadSecurityState();
    
    if (_lockoutTime == null) return false;
    
    final now = DateTime.now();
    final timeSinceLockout = now.difference(_lockoutTime!);
    
    if (timeSinceLockout >= _lockoutDuration) {
      // Lockout period has expired
      await _clearLockout();
      return false;
    }
    
    return true;
  }

  /// Get remaining lockout time
  Future<Duration?> getRemainingLockoutTime() async {
    if (!await isLockedOut()) return null;
    
    final now = DateTime.now();
    final timeSinceLockout = now.difference(_lockoutTime!);
    final remaining = _lockoutDuration - timeSinceLockout;
    
    return remaining.isNegative ? null : remaining;
  }

  /// Set up a new PIN
  Future<PinSetupResult> setupPin(String pin) async {
    try {
      // Validate PIN strength
      final validation = _validatePinStrength(pin);
      if (!validation.isValid) {
        return PinSetupResult(
          success: false,
          message: validation.message,
        );
      }

      // Generate salt and hash
      final salt = _generateSalt();
      final hashedPin = _hashPin(pin, salt);
      
      // Save to secure storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pinHashKey, hashedPin);
      await prefs.setString(_pinSaltKey, salt);
      await prefs.setBool(_pinEnabledKey, true);
      await prefs.setBool(_pinSetupKey, true);
      
      AppLogger.log('PIN setup completed successfully');
      return PinSetupResult(
        success: true,
        message: 'PIN setup completed successfully',
      );
    } catch (e) {
      AppLogger.log('Error setting up PIN: $e');
      await _errorHandler.handleError(
        errorType: ErrorHandlingService.unknownError,
        errorMessage: e.toString(),
        userFriendlyMessage: 'Failed to setup PIN. Please try again.',
      );
      return PinSetupResult(
        success: false,
        message: 'Failed to setup PIN. Please try again.',
      );
    }
  }

  /// Change existing PIN
  Future<PinChangeResult> changePin(String currentPin, String newPin) async {
    try {
      // Verify current PIN
      final currentPinValid = await _verifyPin(currentPin);
      if (!currentPinValid) {
        return PinChangeResult(
          success: false,
          message: 'Current PIN is incorrect',
        );
      }

      // Validate new PIN strength
      final validation = _validatePinStrength(newPin);
      if (!validation.isValid) {
        return PinChangeResult(
          success: false,
          message: validation.message,
        );
      }

      // Check if new PIN is different from current
      if (currentPin == newPin) {
        return PinChangeResult(
          success: false,
          message: 'New PIN must be different from current PIN',
        );
      }

      // Generate new salt and hash
      final salt = _generateSalt();
      final hashedPin = _hashPin(newPin, salt);
      
      // Save to secure storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pinHashKey, hashedPin);
      await prefs.setString(_pinSaltKey, salt);
      
      // Reset security state
      await _clearFailedAttempts();
      
      AppLogger.log('PIN changed successfully');
      return PinChangeResult(
        success: true,
        message: 'PIN changed successfully',
      );
    } catch (e) {
      AppLogger.log('Error changing PIN: $e');
      await _errorHandler.handleError(
        errorType: ErrorHandlingService.unknownError,
        errorMessage: e.toString(),
        userFriendlyMessage: 'Failed to change PIN. Please try again.',
      );
      return PinChangeResult(
        success: false,
        message: 'Failed to change PIN. Please try again.',
      );
    }
  }

  /// Authenticate with PIN
  Future<PinAuthResult> authenticate(String pin, {bool sensitiveTransaction = false}) async {
    try {
      // Check if locked out
      if (await isLockedOut()) {
        final remaining = await getRemainingLockoutTime();
        final minutes = remaining?.inMinutes ?? 0;
        return PinAuthResult(
          success: false,
          errorType: PinErrorType.lockedOut,
          message: 'Account locked. Try again in $minutes minutes.',
        );
      }

      // Check session timeout for sensitive transactions
      if (sensitiveTransaction && !_isSessionValid()) {
        // Force fresh authentication for sensitive operations
        _lastAuthTime = null;
      } else if (_isSessionValid() && !sensitiveTransaction) {
        // Use cached authentication for non-sensitive operations
        return PinAuthResult(
          success: true,
          message: 'Authentication successful (cached)',
        );
      }

      // Verify PIN
      final isValid = await _verifyPin(pin);
      
      if (isValid) {
        _lastAuthTime = DateTime.now();
        await _updateLastAuthTime();
        await _clearFailedAttempts();
        
        AppLogger.log('PIN authentication successful');
        return PinAuthResult(
          success: true,
          message: 'Authentication successful',
        );
      } else {
        await _handleFailedAttempt();
        
        final attemptsLeft = _maxFailedAttempts - _failedAttempts;
        if (attemptsLeft <= 0) {
          return PinAuthResult(
            success: false,
            errorType: PinErrorType.lockedOut,
            message: 'Too many failed attempts. Account locked for ${_lockoutDuration.inMinutes} minutes.',
          );
        } else {
          return PinAuthResult(
            success: false,
            errorType: PinErrorType.incorrectPin,
            message: 'Incorrect PIN. $attemptsLeft attempts remaining.',
          );
        }
      }
    } catch (e) {
      AppLogger.log('PIN authentication error: $e');
      await _errorHandler.handleError(
        errorType: ErrorHandlingService.authError,
        errorMessage: e.toString(),
        userFriendlyMessage: 'Authentication failed. Please try again.',
      );
      return PinAuthResult(
        success: false,
        errorType: PinErrorType.unknown,
        message: 'Authentication failed. Please try again.',
      );
    }
  }

  /// Show PIN input dialog
  Future<String?> showPinInputDialog({
    required String title,
    required String message,
    bool isSetup = false,
  }) async {
    String pin = '';
    
    return await Get.dialog<String>(
      AlertDialog(
        backgroundColor: CustomColor.surfaceColor,
        title: Text(
          title,
          style: CustomStyle.commonTextTitleWhite.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: CustomStyle.commonTextTitleWhite.copyWith(
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            // PIN dots display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < pin.length 
                        ? CustomColor.primaryColor 
                        : Colors.grey[600],
                    border: Border.all(
                      color: CustomColor.primaryColor,
                      width: 1,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            // Number pad
            SizedBox(
              width: 200,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  if (index == 9) {
                    // Empty space
                    return const SizedBox();
                  } else if (index == 10) {
                    // Zero
                    return _buildNumberButton('0', () {
                      if (pin.length < 6) {
                        pin += '0';
                        (context as Element).markNeedsBuild();
                      }
                    });
                  } else if (index == 11) {
                    // Backspace
                    return _buildNumberButton('⌫', () {
                      if (pin.isNotEmpty) {
                        pin = pin.substring(0, pin.length - 1);
                        (context as Element).markNeedsBuild();
                      }
                    });
                  } else {
                    // Numbers 1-9
                    final number = (index + 1).toString();
                    return _buildNumberButton(number, () {
                      if (pin.length < 6) {
                        pin += number;
                        (context as Element).markNeedsBuild();
                      }
                    });
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: pin.length >= 4 ? () => Get.back(result: pin) : null,
            child: Text(
              'Confirm',
              style: TextStyle(
                color: pin.length >= 4 ? CustomColor.primaryColor : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberButton(String text, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.grey[600]!,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: CustomStyle.commonTextTitleWhite.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Quick authentication for app unlock
  Future<bool> quickAuthenticate() async {
    final pin = await showPinInputDialog(
      title: 'Enter PIN',
      message: 'Please enter your PIN to access your account',
    );
    
    if (pin == null) return false;
    
    final result = await authenticate(pin, sensitiveTransaction: false);
    return result.success;
  }

  /// Secure authentication for sensitive operations
  Future<bool> secureAuthenticate({required String operation}) async {
    final pin = await showPinInputDialog(
      title: 'Security Verification',
      message: 'Please enter your PIN to $operation',
    );
    
    if (pin == null) return false;
    
    final result = await authenticate(pin, sensitiveTransaction: true);
    return result.success;
  }

  /// Disable PIN authentication
  Future<bool> disablePin(String currentPin) async {
    try {
      // Verify current PIN
      final isValid = await _verifyPin(currentPin);
      if (!isValid) {
        await _errorHandler.handleValidationError(
          field: 'PIN',
          message: 'Current PIN is incorrect',
        );
        return false;
      }

      // Clear PIN data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pinHashKey);
      await prefs.remove(_pinSaltKey);
      await prefs.setBool(_pinEnabledKey, false);
      await _clearFailedAttempts();
      
      AppLogger.log('PIN authentication disabled');
      return true;
    } catch (e) {
      AppLogger.log('Error disabling PIN: $e');
      await _errorHandler.handleError(
        errorType: ErrorHandlingService.unknownError,
        errorMessage: e.toString(),
        userFriendlyMessage: 'Failed to disable PIN. Please try again.',
      );
      return false;
    }
  }

  // Private helper methods
  
  Future<bool> _verifyPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedHash = prefs.getString(_pinHashKey);
      final storedSalt = prefs.getString(_pinSaltKey);
      
      if (storedHash == null || storedSalt == null) {
        return false;
      }
      
      final hashedInput = _hashPin(pin, storedSalt);
      return hashedInput == storedHash;
    } catch (e) {
      AppLogger.log('Error verifying PIN: $e');
      return false;
    }
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode(pin + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _generateSalt() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final bytes = utf8.encode(timestamp);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  PinValidationResult _validatePinStrength(String pin) {
    if (pin.length < 4) {
      return PinValidationResult(
        isValid: false,
        message: 'PIN must be at least 4 digits long',
      );
    }
    
    if (pin.length > 6) {
      return PinValidationResult(
        isValid: false,
        message: 'PIN must be no more than 6 digits long',
      );
    }
    
    // Check for weak patterns
    if (RegExp(r'^(\d)\1+$').hasMatch(pin)) {
      return PinValidationResult(
        isValid: false,
        message: 'PIN cannot be all the same digit',
      );
    }
    
    if (pin == '1234' || pin == '0000' || pin == '1111' || pin == '1357' || pin == '2468') {
      return PinValidationResult(
        isValid: false,
        message: 'PIN is too common. Please choose a more secure PIN',
      );
    }
    
    return PinValidationResult(
      isValid: true,
      message: 'PIN is valid',
    );
  }

  bool _isSessionValid() {
    if (_lastAuthTime == null) return false;
    
    final now = DateTime.now();
    final timeDifference = now.difference(_lastAuthTime!);
    
    return timeDifference < _sessionTimeout;
  }

  Future<void> _handleFailedAttempt() async {
    _failedAttempts++;
    
    if (_failedAttempts >= _maxFailedAttempts) {
      _lockoutTime = DateTime.now();
      await _saveLockoutTime();
    }
    
    await _saveFailedAttempts();
  }

  Future<void> _clearFailedAttempts() async {
    _failedAttempts = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_failedAttemptsKey);
  }

  Future<void> _clearLockout() async {
    _lockoutTime = null;
    _failedAttempts = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lockoutTimeKey);
    await prefs.remove(_failedAttemptsKey);
  }

  Future<void> _saveFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_failedAttemptsKey, _failedAttempts);
  }

  Future<void> _saveLockoutTime() async {
    if (_lockoutTime != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lockoutTimeKey, _lockoutTime!.millisecondsSinceEpoch);
    }
  }

  Future<void> _loadSecurityState() async {
    final prefs = await SharedPreferences.getInstance();
    
    _failedAttempts = prefs.getInt(_failedAttemptsKey) ?? 0;
    
    final lockoutTimestamp = prefs.getInt(_lockoutTimeKey);
    if (lockoutTimestamp != null) {
      _lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutTimestamp);
    }
    
    final lastAuthTimestamp = prefs.getInt(_lastPinAuthKey);
    if (lastAuthTimestamp != null) {
      _lastAuthTime = DateTime.fromMillisecondsSinceEpoch(lastAuthTimestamp);
    }
  }

  Future<void> _updateLastAuthTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastPinAuthKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      AppLogger.log('Error updating last auth time: $e');
    }
  }

  /// Invalidate current session
  Future<void> invalidateSession() async {
    _lastAuthTime = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastPinAuthKey);
      AppLogger.log('PIN session invalidated');
    } catch (e) {
      AppLogger.log('Error invalidating session: $e');
    }
  }

  /// Initialize service
  Future<void> initialize() async {
    await _loadSecurityState();
    AppLogger.log('PinAuthService initialized');
  }
}

/// PIN setup result
class PinSetupResult {
  final bool success;
  final String message;
  
  const PinSetupResult({
    required this.success,
    required this.message,
  });
}

/// PIN change result
class PinChangeResult {
  final bool success;
  final String message;
  
  const PinChangeResult({
    required this.success,
    required this.message,
  });
}

/// PIN authentication result
class PinAuthResult {
  final bool success;
  final PinErrorType? errorType;
  final String message;
  
  const PinAuthResult({
    required this.success,
    this.errorType,
    required this.message,
  });
}

/// PIN validation result
class PinValidationResult {
  final bool isValid;
  final String message;
  
  const PinValidationResult({
    required this.isValid,
    required this.message,
  });
}

/// PIN error types
enum PinErrorType {
  incorrectPin,
  lockedOut,
  notSetup,
  unknown,
}