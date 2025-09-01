import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';
import '../config/subscription_config.dart';
import '../utils/app_logger.dart';
import 'purchase_validation_service.dart';

/// Apple App Store specific subscription management service
class AppleSubscriptionService {
  static final AppleSubscriptionService _instance = AppleSubscriptionService._internal();
  factory AppleSubscriptionService() => _instance;
  AppleSubscriptionService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final GetStorage _storage = GetStorage();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Apple-specific storage keys
  static const String _appleReceiptKey = 'apple_receipt_data';
  static const String _appleTransactionIdKey = 'apple_transaction_id';
  static const String _appleOriginalTransactionIdKey = 'apple_original_transaction_id';
  static const String _appleSubscriptionGroupIdKey = 'apple_subscription_group_id';
  static const String _appleEnvironmentKey = 'apple_environment';

  // Apple subscription state
  String? _latestReceiptData;
  String? _transactionId;
  String? _originalTransactionId;
  bool _isAppleSubscriptionActive = false;
  DateTime? _appleExpiryDate;

  // Getters for Apple-specific data
  bool get isAppleSubscriptionActive => _isAppleSubscriptionActive;
  DateTime? get appleExpiryDate => _appleExpiryDate;
  String? get latestReceiptData => _latestReceiptData;
  String? get transactionId => _transactionId;
  String? get originalTransactionId => _originalTransactionId;

  /// Initialize Apple subscription service
  Future<void> initialize() async {
    if (!io.Platform.isIOS) {
      AppLogger.log('Apple Subscription Service: Not running on iOS, skipping initialization');
      return;
    }

    AppLogger.log('Initializing Apple Subscription Service...');
    
    try {
      // Load stored Apple subscription data
      await _loadAppleSubscriptionData();
      
      // Check for existing Apple subscriptions
      await _checkAppleSubscriptions();
      
      AppLogger.log('Apple Subscription Service initialized successfully');
    } catch (e) {
      AppLogger.log('Error initializing Apple Subscription Service: $e');
    }
  }

  /// Load stored Apple subscription data
  Future<void> _loadAppleSubscriptionData() async {
    try {
      _latestReceiptData = _storage.read(_appleReceiptKey);
      _transactionId = _storage.read(_appleTransactionIdKey);
      _originalTransactionId = _storage.read(_appleOriginalTransactionIdKey);
      
      AppLogger.log('Loaded Apple subscription data from storage');
    } catch (e) {
      AppLogger.log('Error loading Apple subscription data: $e');
    }
  }

  /// Check existing Apple subscriptions
  Future<void> _checkAppleSubscriptions() async {
    try {
      // Restore Apple purchases
      await _inAppPurchase.restorePurchases();
      
      // If we have stored receipt data, validate it
      if (_latestReceiptData != null) {
        await _validateAppleReceipt(_latestReceiptData!);
      }
    } catch (e) {
      AppLogger.log('Error checking Apple subscriptions: $e');
    }
  }

  /// Purchase Apple subscription
  Future<bool> purchaseAppleSubscription() async {
    if (!io.Platform.isIOS) {
      AppLogger.log('Cannot purchase Apple subscription on non-iOS platform');
      return false;
    }

    try {
      AppLogger.log('Starting Apple subscription purchase...');
      
      // Get Apple product details
      final productId = SubscriptionConfig.iosSubscriptionId;
      final response = await _inAppPurchase.queryProductDetails({productId});
      
      if (response.productDetails.isEmpty) {
        AppLogger.log('Apple subscription product not found: $productId');
        return false;
      }

      final productDetails = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: productDetails);
      
      // Initiate purchase
      final success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      
      AppLogger.log('Apple subscription purchase initiated: $success');
      return success;
    } catch (e) {
      AppLogger.log('Error purchasing Apple subscription: $e');
      return false;
    }
  }

  /// Handle Apple purchase completion
  Future<void> handleApplePurchase(PurchaseDetails purchaseDetails) async {
    try {
      AppLogger.log('Handling Apple purchase: ${purchaseDetails.productID}');
      
      if (purchaseDetails.productID == SubscriptionConfig.iosSubscriptionId) {
        // Extract Apple-specific data
        _transactionId = purchaseDetails.purchaseID;
        
        // For iOS, the receipt data is in verificationData.localVerificationData
        if (purchaseDetails.verificationData.localVerificationData.isNotEmpty) {
          _latestReceiptData = purchaseDetails.verificationData.localVerificationData;
          
          // Validate receipt with Apple servers
          final isValid = await _validateAppleReceipt(_latestReceiptData!);
          
          if (isValid) {
            // Save Apple subscription data
            await _saveAppleSubscriptionData();
            
            // Update subscription status
            _isAppleSubscriptionActive = true;
            
            AppLogger.log('Apple subscription activated successfully');
          }
        }
      }
    } catch (e) {
      AppLogger.log('Error handling Apple purchase: $e');
    }
  }

  /// Validate Apple receipt with server
  Future<bool> _validateAppleReceipt(String receiptData) async {
    try {
      AppLogger.log('Validating Apple receipt...');
      
      final user = _auth.currentUser;
      if (user == null) {
        AppLogger.log('No authenticated user for Apple receipt validation');
        return false;
      }

      // Call Firebase Function for Apple receipt validation
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('validateAppleReceipt');
      
      final result = await callable.call({
        'receiptData': receiptData,
        'userId': user.uid,
        'productId': SubscriptionConfig.iosSubscriptionId,
        'environment': 'production', // or 'sandbox' for testing
      });

      if (result.data['success'] == true) {
        final receiptInfo = result.data['receipt'];
        
        // Extract expiry date from receipt
        if (receiptInfo['expires_date_ms'] != null) {
          final expiryMs = int.parse(receiptInfo['expires_date_ms'].toString());
          _appleExpiryDate = DateTime.fromMillisecondsSinceEpoch(expiryMs);
        }
        
        // Extract original transaction ID
        if (receiptInfo['original_transaction_id'] != null) {
          _originalTransactionId = receiptInfo['original_transaction_id'];
        }
        
        AppLogger.log('Apple receipt validation successful');
        return true;
      } else {
        AppLogger.log('Apple receipt validation failed: ${result.data['error']}');
        return false;
      }
    } catch (e) {
      AppLogger.log('Error validating Apple receipt: $e');
      return false;
    }
  }

  /// Save Apple subscription data to storage
  Future<void> _saveAppleSubscriptionData() async {
    try {
      if (_latestReceiptData != null) {
        await _storage.write(_appleReceiptKey, _latestReceiptData);
      }
      if (_transactionId != null) {
        await _storage.write(_appleTransactionIdKey, _transactionId);
      }
      if (_originalTransactionId != null) {
        await _storage.write(_appleOriginalTransactionIdKey, _originalTransactionId);
      }
      
      AppLogger.log('Apple subscription data saved to storage');
    } catch (e) {
      AppLogger.log('Error saving Apple subscription data: $e');
    }
  }

  /// Get Apple subscription status
  Future<Map<String, dynamic>> getAppleSubscriptionStatus() async {
    try {
      if (_latestReceiptData != null) {
        // Validate current receipt
        final isValid = await _validateAppleReceipt(_latestReceiptData!);
        
        return {
          'isActive': isValid && _isAppleSubscriptionActive,
          'expiryDate': _appleExpiryDate?.toIso8601String(),
          'transactionId': _transactionId,
          'originalTransactionId': _originalTransactionId,
          'platform': 'apple',
          'productId': SubscriptionConfig.iosSubscriptionId,
        };
      }
      
      return {
        'isActive': false,
        'platform': 'apple',
        'productId': SubscriptionConfig.iosSubscriptionId,
      };
    } catch (e) {
      AppLogger.log('Error getting Apple subscription status: $e');
      return {
        'isActive': false,
        'error': e.toString(),
        'platform': 'apple',
      };
    }
  }

  /// Cancel Apple subscription (redirect to App Store)
  Future<void> cancelAppleSubscription() async {
    try {
      AppLogger.log('Redirecting to App Store for subscription management');
      
      // On iOS, users must cancel subscriptions through the App Store
      // We can only provide guidance or redirect them
      Get.dialog(
        AlertDialog(
          title: const Text('Manage Subscription'),
          content: const Text(
            'To cancel your subscription, please go to:\n\n'
            '1. iPhone Settings\n'
            '2. Your Name (Apple ID)\n'
            '3. Subscriptions\n'
            '4. Find "Digital Payments -Premium"\n'
            '5. Tap "Cancel Subscription"',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      AppLogger.log('Error handling Apple subscription cancellation: $e');
    }
  }

  /// Clear Apple subscription data
  Future<void> clearAppleSubscriptionData() async {
    try {
      await _storage.remove(_appleReceiptKey);
      await _storage.remove(_appleTransactionIdKey);
      await _storage.remove(_appleOriginalTransactionIdKey);
      
      _latestReceiptData = null;
      _transactionId = null;
      _originalTransactionId = null;
      _isAppleSubscriptionActive = false;
      _appleExpiryDate = null;
      
      AppLogger.log('Apple subscription data cleared');
    } catch (e) {
      AppLogger.log('Error clearing Apple subscription data: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    AppLogger.log('Disposing Apple Subscription Service');
  }
}