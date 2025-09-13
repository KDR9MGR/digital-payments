import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../utils/app_logger.dart';

/// Comprehensive fallback service for subscription validation failures
class SubscriptionFallbackService {
  static final SubscriptionFallbackService _instance = SubscriptionFallbackService._internal();
  factory SubscriptionFallbackService() => _instance;
  SubscriptionFallbackService._internal();

  final GetStorage _storage = GetStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Storage keys for fallback data
  static const String _fallbackSubscriptionKey = 'fallback_subscription_status';
  static const String _lastSuccessfulValidationKey = 'last_successful_validation';
  static const String _validationFailureCountKey = 'validation_failure_count';
  static const String _lastValidationAttemptKey = 'last_validation_attempt';
  static const String _offlineSubscriptionDataKey = 'offline_subscription_data';
  static const String _platformReceiptBackupKey = 'platform_receipt_backup';

  // Fallback configuration
  static const int _maxValidationFailures = 5;
  static const Duration _offlineGracePeriod = Duration(days: 3);

  /// Initialize fallback service
  Future<void> initialize() async {
    try {
      AppLogger.log('Initializing subscription fallback service...');
      await _cleanupExpiredFallbackData();
      AppLogger.log('Subscription fallback service initialized successfully');
    } catch (e) {
      AppLogger.log('Error initializing fallback service: $e');
    }
  }

  /// Handle subscription validation failure with comprehensive fallback strategies
  Future<bool> handleValidationFailure({
    required String failureReason,
    required String userId,
    Map<String, dynamic>? lastKnownSubscriptionData,
  }) async {
    try {
      AppLogger.log('Handling subscription validation failure: $failureReason');
      
      // Increment failure count
      final failureCount = _incrementFailureCount();
      
      // Try multiple fallback strategies in order of preference
      
      // Strategy 1: Platform receipt validation
      if (await _tryPlatformReceiptValidation(userId)) {
        AppLogger.log('Fallback successful: Platform receipt validation');
        _resetFailureCount();
        return true;
      }
      
      // Strategy 2: Cached subscription data validation
      if (await _tryCachedDataValidation(userId)) {
        AppLogger.log('Fallback successful: Cached data validation');
        return true;
      }
      
      // Strategy 3: Firestore direct query (bypass Cloud Functions)
      if (await _tryFirestoreDirectQuery(userId)) {
        AppLogger.log('Fallback successful: Firestore direct query');
        _resetFailureCount();
        return true;
      }
      
      // Strategy 4: Offline grace period
      if (await _tryOfflineGracePeriod(userId, lastKnownSubscriptionData)) {
        AppLogger.log('Fallback successful: Offline grace period activated');
        return true;
      }
      
      AppLogger.log('All fallback strategies failed');
      return false;
      
    } catch (e) {
      AppLogger.log('Error in fallback handling: $e');
      return false;
    }
  }

  /// Strategy 1: Try platform receipt validation
  Future<bool> _tryPlatformReceiptValidation(String userId) async {
    try {
      AppLogger.log('Attempting platform receipt validation fallback...');
      
      // Get stored receipt data
      final receiptData = _storage.read(_platformReceiptBackupKey);
      if (receiptData == null) {
        AppLogger.log('No platform receipt data available');
        return false;
      }
      
      // Try to validate with platform stores directly
      if (Platform.isIOS) {
        return await _validateAppleReceiptFallback(receiptData, userId);
      } else if (Platform.isAndroid) {
        return await _validateGoogleReceiptFallback(receiptData, userId);
      }
      
      return false;
    } catch (e) {
      AppLogger.log('Platform receipt validation fallback failed: $e');
      return false;
    }
  }

  /// Strategy 2: Try cached subscription data validation
  Future<bool> _tryCachedDataValidation(String userId) async {
    try {
      AppLogger.log('Attempting cached data validation fallback...');
      
      final lastSuccessfulValidation = _storage.read(_lastSuccessfulValidationKey);
      if (lastSuccessfulValidation == null) {
        return false;
      }
      
      final validationTime = DateTime.fromMillisecondsSinceEpoch(lastSuccessfulValidation);
      final timeSinceValidation = DateTime.now().difference(validationTime);
      
      // Allow cached data if last successful validation was within 24 hours
      if (timeSinceValidation.inHours <= 24) {
        final cachedData = _storage.read(_fallbackSubscriptionKey);
        if (cachedData != null && cachedData == true) {
          AppLogger.log('Using cached subscription data (${timeSinceValidation.inHours} hours old)');
          return true;
        }
      }
      
      return false;
    } catch (e) {
      AppLogger.log('Cached data validation fallback failed: $e');
      return false;
    }
  }

  /// Strategy 3: Try Firestore direct query
  Future<bool> _tryFirestoreDirectQuery(String userId) async {
    try {
      AppLogger.log('Attempting Firestore direct query fallback...');
      
      // Query user's subscription document directly
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        final userData = userDoc.data();
        final subscriptionStatus = userData?['subscriptionStatus'];
        final expiryDate = userData?['subscriptionExpiry'];
        
        if (subscriptionStatus == 'active' && expiryDate != null) {
          final expiry = (expiryDate as Timestamp).toDate();
          if (DateTime.now().isBefore(expiry)) {
            AppLogger.log('Firestore direct query confirmed active subscription');
            _saveSuccessfulValidation(true);
            return true;
          }
        }
      }
      
      // Also check subscriptions collection
      final subscriptionsQuery = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      
      if (subscriptionsQuery.docs.isNotEmpty) {
        final subscription = subscriptionsQuery.docs.first.data();
        final expiryDate = subscription['currentPeriodEnd'];
        
        if (expiryDate != null) {
          final expiry = (expiryDate as Timestamp).toDate();
          if (DateTime.now().isBefore(expiry)) {
            AppLogger.log('Firestore subscriptions collection confirmed active subscription');
            _saveSuccessfulValidation(true);
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      AppLogger.log('Firestore direct query fallback failed: $e');
      return false;
    }
  }

  /// Strategy 4: Try offline grace period
  Future<bool> _tryOfflineGracePeriod(String userId, Map<String, dynamic>? lastKnownData) async {
    try {
      AppLogger.log('Attempting offline grace period fallback...');
      
      if (lastKnownData == null) {
        return false;
      }
      
      final offlineData = _storage.read(_offlineSubscriptionDataKey);
      if (offlineData != null) {
        final data = Map<String, dynamic>.from(offlineData);
        final gracePeriodStart = DateTime.fromMillisecondsSinceEpoch(data['gracePeriodStart']);
        final gracePeriodEnd = gracePeriodStart.add(_offlineGracePeriod);
        
        if (DateTime.now().isBefore(gracePeriodEnd)) {
          AppLogger.log('Offline grace period still active');
          return true;
        } else {
          // Grace period expired, clear data
          _storage.remove(_offlineSubscriptionDataKey);
          return false;
        }
      } else {
        // Start new offline grace period
        final gracePeriodData = {
          'gracePeriodStart': DateTime.now().millisecondsSinceEpoch,
          'lastKnownSubscriptionData': lastKnownData,
          'userId': userId,
        };
        
        _storage.write(_offlineSubscriptionDataKey, gracePeriodData);
        AppLogger.log('Started offline grace period');
        
        // Show user notification about offline mode
        _showOfflineGracePeriodNotification();
        
        return true;
      }
    } catch (e) {
      AppLogger.log('Offline grace period fallback failed: $e');
      return false;
    }
  }



  /// Validate Apple receipt as fallback
  Future<bool> _validateAppleReceiptFallback(Map<String, dynamic> receiptData, String userId) async {
    try {
      // Implement Apple receipt validation logic
      // This would involve calling Apple's verification servers directly
      AppLogger.log('Apple receipt fallback validation not yet implemented');
      return false;
    } catch (e) {
      AppLogger.log('Apple receipt fallback validation failed: $e');
      return false;
    }
  }

  /// Validate Google receipt as fallback
  Future<bool> _validateGoogleReceiptFallback(Map<String, dynamic> receiptData, String userId) async {
    try {
      // Implement Google Play receipt validation logic
      // This would involve calling Google Play Developer API directly
      AppLogger.log('Google receipt fallback validation not yet implemented');
      return false;
    } catch (e) {
      AppLogger.log('Google receipt fallback validation failed: $e');
      return false;
    }
  }



  /// Check if in offline grace period
  bool isInOfflineGracePeriod() {
    try {
      final offlineData = _storage.read(_offlineSubscriptionDataKey);
      if (offlineData == null) return false;
      
      final data = Map<String, dynamic>.from(offlineData);
      final gracePeriodStart = DateTime.fromMillisecondsSinceEpoch(data['gracePeriodStart']);
      final gracePeriodEnd = gracePeriodStart.add(_offlineGracePeriod);
      
      return DateTime.now().isBefore(gracePeriodEnd);
    } catch (e) {
      AppLogger.log('Error checking offline grace period: $e');
      return false;
    }
  }

  /// Save successful validation data
  void _saveSuccessfulValidation(bool subscriptionStatus) {
    _storage.write(_lastSuccessfulValidationKey, DateTime.now().millisecondsSinceEpoch);
    _storage.write(_fallbackSubscriptionKey, subscriptionStatus);
    _resetFailureCount();
  }

  /// Increment and return failure count
  int _incrementFailureCount() {
    final currentCount = _storage.read(_validationFailureCountKey) ?? 0;
    final newCount = currentCount + 1;
    _storage.write(_validationFailureCountKey, newCount);
    _storage.write(_lastValidationAttemptKey, DateTime.now().millisecondsSinceEpoch);
    return newCount;
  }

  /// Reset failure count
  void _resetFailureCount() {
    _storage.remove(_validationFailureCountKey);
    _storage.remove(_lastValidationAttemptKey);
  }

  /// Clean up expired fallback data
  Future<void> _cleanupExpiredFallbackData() async {
    try {
      // Clean up expired offline grace period
      final offlineData = _storage.read(_offlineSubscriptionDataKey);
      if (offlineData != null) {
        final data = Map<String, dynamic>.from(offlineData);
        final gracePeriodStart = DateTime.fromMillisecondsSinceEpoch(data['gracePeriodStart']);
        final gracePeriodEnd = gracePeriodStart.add(_offlineGracePeriod);
        if (DateTime.now().isAfter(gracePeriodEnd)) {
          _storage.remove(_offlineSubscriptionDataKey);
        }
      }
      
      AppLogger.log('Fallback data cleanup completed');
    } catch (e) {
      AppLogger.log('Error during fallback data cleanup: $e');
    }
  }

  /// Show offline grace period notification
  void _showOfflineGracePeriodNotification() {
    Get.snackbar(
      'Offline Mode Active',
      'Unable to verify subscription online. You have ${_offlineGracePeriod.inDays} days of offline access.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Get.theme.colorScheme.tertiary,
      colorText: Get.theme.colorScheme.onTertiary,
      duration: const Duration(seconds: 6),
      isDismissible: true,
    );
  }



  /// Store platform receipt for fallback validation
  void storePlatformReceipt(Map<String, dynamic> receiptData) {
    try {
      _storage.write(_platformReceiptBackupKey, receiptData);
      AppLogger.log('Platform receipt stored for fallback validation');
    } catch (e) {
      AppLogger.log('Error storing platform receipt: $e');
    }
  }

  /// Get fallback status summary
  Map<String, dynamic> getFallbackStatus() {
    return {
      'isInOfflineGracePeriod': isInOfflineGracePeriod(),
      'validationFailureCount': _storage.read(_validationFailureCountKey) ?? 0,
      'lastValidationAttempt': _storage.read(_lastValidationAttemptKey),
      'lastSuccessfulValidation': _storage.read(_lastSuccessfulValidationKey),
    };
  }

  /// Dispose and cleanup
  void dispose() {
    AppLogger.log('Subscription fallback service disposed');
  }
}