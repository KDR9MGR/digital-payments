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

/// Google Play Store specific subscription management service
class GoogleSubscriptionService {
  static final GoogleSubscriptionService _instance =
      GoogleSubscriptionService._internal();
  factory GoogleSubscriptionService() => _instance;
  GoogleSubscriptionService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final GetStorage _storage = GetStorage();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Google Play specific storage keys
  static const String _googlePurchaseTokenKey = 'google_purchase_token';
  static const String _googleOrderIdKey = 'google_order_id';
  static const String _googlePackageNameKey = 'google_package_name';
  static const String _googleSubscriptionIdKey = 'google_subscription_id';
  static const String _googleAcknowledgedKey = 'google_acknowledged';

  // Google subscription state
  String? _purchaseToken;
  String? _orderId;
  String? _packageName;
  bool _isGoogleSubscriptionActive = false;
  bool _isAcknowledged = false;
  DateTime? _googleExpiryDate;
  DateTime? _googleStartDate;

  // Getters for Google-specific data
  bool get isGoogleSubscriptionActive => _isGoogleSubscriptionActive;
  DateTime? get googleExpiryDate => _googleExpiryDate;
  DateTime? get googleStartDate => _googleStartDate;
  String? get purchaseToken => _purchaseToken;
  String? get orderId => _orderId;
  bool get isAcknowledged => _isAcknowledged;

  /// Initialize Google subscription service
  Future<void> initialize() async {
    if (!io.Platform.isAndroid) {
      AppLogger.log(
        'Google Subscription Service: Not running on Android, skipping initialization',
      );
      return;
    }

    AppLogger.log('Initializing Google Subscription Service...');

    try {
      // Load stored Google subscription data
      await _loadGoogleSubscriptionData();

      // Check for existing Google subscriptions
      await _checkGoogleSubscriptions();

      AppLogger.log('Google Subscription Service initialized successfully');
    } catch (e) {
      AppLogger.log('Error initializing Google Subscription Service: $e');
    }
  }

  /// Load stored Google subscription data
  Future<void> _loadGoogleSubscriptionData() async {
    try {
      _purchaseToken = _storage.read(_googlePurchaseTokenKey);
      _orderId = _storage.read(_googleOrderIdKey);
      _packageName =
          _storage.read(_googlePackageNameKey) ?? 'com.digitalpayments';
      _isAcknowledged = _storage.read(_googleAcknowledgedKey) ?? false;

      AppLogger.log('Loaded Google subscription data from storage');
    } catch (e) {
      AppLogger.log('Error loading Google subscription data: $e');
    }
  }

  /// Check existing Google subscriptions
  Future<void> _checkGoogleSubscriptions() async {
    try {
      // Restore Google Play purchases
      await _inAppPurchase.restorePurchases();

      // If we have stored purchase token, validate it
      if (_purchaseToken != null) {
        await _validateGooglePurchase(_purchaseToken!);
      }
    } catch (e) {
      AppLogger.log('Error checking Google subscriptions: $e');
    }
  }

  /// Purchase Google subscription
  Future<bool> purchaseGoogleSubscription() async {
    if (!io.Platform.isAndroid) {
      AppLogger.log(
        'Cannot purchase Google subscription on non-Android platform',
      );
      return false;
    }

    try {
      AppLogger.log('Starting Google subscription purchase...');

      // Get Google product details
      final productId = SubscriptionConfig.androidSubscriptionId;
      final response = await _inAppPurchase.queryProductDetails({productId});

      if (response.productDetails.isEmpty) {
        AppLogger.log('Google subscription product not found: $productId');
        return false;
      }

      final productDetails = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: productDetails);

      // Initiate purchase
      final success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      AppLogger.log('Google subscription purchase initiated: $success');
      return success;
    } catch (e) {
      AppLogger.log('Error purchasing Google subscription: $e');
      return false;
    }
  }

  /// Handle Google purchase completion
  Future<void> handleGooglePurchase(PurchaseDetails purchaseDetails) async {
    try {
      AppLogger.log('Handling Google purchase: ${purchaseDetails.productID}');

      if (purchaseDetails.productID ==
          SubscriptionConfig.androidSubscriptionId) {
        // Extract Google-specific data
        _orderId = purchaseDetails.purchaseID;
        _packageName = 'com.digitalpayments'; // Your app's package name

        // For Android, the purchase token is in verificationData.serverVerificationData
        if (purchaseDetails
            .verificationData
            .serverVerificationData
            .isNotEmpty) {
          // Parse the purchase data to extract purchase token
          final purchaseData = json.decode(
            purchaseDetails.verificationData.localVerificationData,
          );
          _purchaseToken = purchaseData['purchaseToken'];

          if (_purchaseToken != null) {
            // Validate purchase with Google Play
            final isValid = await _validateGooglePurchase(_purchaseToken!);

            if (isValid) {
              // Acknowledge the purchase if not already acknowledged
              if (!_isAcknowledged) {
                await _acknowledgePurchase(purchaseDetails);
              }

              // Save Google subscription data
              await _saveGoogleSubscriptionData();

              // Update subscription status
              _isGoogleSubscriptionActive = true;

              AppLogger.log('Google subscription activated successfully');
            }
          }
        }
      }
    } catch (e) {
      AppLogger.log('Error handling Google purchase: $e');
    }
  }

  /// Acknowledge Google Play purchase
  Future<void> _acknowledgePurchase(PurchaseDetails purchaseDetails) async {
    try {
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
        _isAcknowledged = true;
        AppLogger.log('Google purchase acknowledged');
      }
    } catch (e) {
      AppLogger.log('Error acknowledging Google purchase: $e');
    }
  }

  /// Validate Google Play purchase with server
  Future<bool> _validateGooglePurchase(String purchaseToken) async {
    try {
      AppLogger.log('Validating Google Play purchase...');

      final user = _auth.currentUser;
      if (user == null) {
        AppLogger.log('No authenticated user for Google purchase validation');
        return false;
      }

      // Call Firebase Function for Google Play validation
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('validateGooglePlayPurchase');

      final result = await callable.call({
        'packageName': _packageName,
        'subscriptionId': SubscriptionConfig.androidSubscriptionId,
        'purchaseToken': purchaseToken,
        'userId': user.uid,
      });

      if (result.data['success'] == true) {
        final purchaseInfo = result.data['purchase'];

        // Extract expiry date from purchase info
        if (purchaseInfo['expiryTimeMillis'] != null) {
          final expiryMs = int.parse(
            purchaseInfo['expiryTimeMillis'].toString(),
          );
          _googleExpiryDate = DateTime.fromMillisecondsSinceEpoch(expiryMs);
        }

        // Extract start date
        if (purchaseInfo['startTimeMillis'] != null) {
          final startMs = int.parse(purchaseInfo['startTimeMillis'].toString());
          _googleStartDate = DateTime.fromMillisecondsSinceEpoch(startMs);
        }

        // Check if purchase is acknowledged
        if (purchaseInfo['acknowledgementState'] != null) {
          _isAcknowledged = purchaseInfo['acknowledgementState'] == 1;
        }

        AppLogger.log('Google Play purchase validation successful');
        return true;
      } else {
        AppLogger.log(
          'Google Play purchase validation failed: ${result.data['error']}',
        );
        return false;
      }
    } catch (e) {
      AppLogger.log('Error validating Google Play purchase: $e');
      return false;
    }
  }

  /// Save Google subscription data to storage
  Future<void> _saveGoogleSubscriptionData() async {
    try {
      if (_purchaseToken != null) {
        await _storage.write(_googlePurchaseTokenKey, _purchaseToken);
      }
      if (_orderId != null) {
        await _storage.write(_googleOrderIdKey, _orderId);
      }
      if (_packageName != null) {
        await _storage.write(_googlePackageNameKey, _packageName);
      }
      await _storage.write(_googleAcknowledgedKey, _isAcknowledged);

      AppLogger.log('Google subscription data saved to storage');
    } catch (e) {
      AppLogger.log('Error saving Google subscription data: $e');
    }
  }

  /// Get Google subscription status
  Future<Map<String, dynamic>> getGoogleSubscriptionStatus() async {
    try {
      if (_purchaseToken != null) {
        // Validate current purchase token
        final isValid = await _validateGooglePurchase(_purchaseToken!);

        return {
          'isActive': isValid && _isGoogleSubscriptionActive,
          'expiryDate': _googleExpiryDate?.toIso8601String(),
          'startDate': _googleStartDate?.toIso8601String(),
          'orderId': _orderId,
          'purchaseToken': _purchaseToken,
          'isAcknowledged': _isAcknowledged,
          'platform': 'google',
          'productId': SubscriptionConfig.androidSubscriptionId,
          'packageName': _packageName,
        };
      }

      return {
        'isActive': false,
        'platform': 'google',
        'productId': SubscriptionConfig.androidSubscriptionId,
        'packageName': _packageName,
      };
    } catch (e) {
      AppLogger.log('Error getting Google subscription status: $e');
      return {'isActive': false, 'error': e.toString(), 'platform': 'google'};
    }
  }

  /// Cancel Google subscription
  Future<void> cancelGoogleSubscription() async {
    try {
      AppLogger.log('Initiating Google subscription cancellation...');

      if (_purchaseToken == null) {
        AppLogger.log('No active Google subscription to cancel');
        return;
      }

      // Call Firebase Function to cancel subscription
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('cancelGoogleSubscription');

      final result = await callable.call({
        'packageName': _packageName,
        'subscriptionId': SubscriptionConfig.androidSubscriptionId,
        'purchaseToken': _purchaseToken,
        'userId': _auth.currentUser?.uid,
      });

      if (result.data['success'] == true) {
        // Update local state
        _isGoogleSubscriptionActive = false;

        AppLogger.log('Google subscription cancelled successfully');

        Get.snackbar(
          'Subscription Cancelled',
          'Your subscription has been cancelled successfully.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.secondary,
          colorText: Get.theme.colorScheme.onSecondary,
        );
      } else {
        AppLogger.log(
          'Failed to cancel Google subscription: ${result.data['error']}',
        );

        // Provide manual cancellation instructions
        Get.dialog(
          AlertDialog(
            title: const Text('Cancel Subscription'),
            content: const Text(
              'To cancel your subscription, please:\n\n'
              '1. Open Google Play Store\n'
              '2. Tap Menu → Subscriptions\n'
              '3. Find "Digital Payments -Premium"\n'
              '4. Tap "Cancel subscription"',
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      AppLogger.log('Error cancelling Google subscription: $e');

      Get.snackbar(
        'Error',
        'Failed to cancel subscription. Please try again or contact support.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    }
  }

  /// Defer Google subscription
  Future<void> deferGoogleSubscription(int deferralDays) async {
    try {
      AppLogger.log('Deferring Google subscription for $deferralDays days...');

      if (_purchaseToken == null) {
        AppLogger.log('No active Google subscription to defer');
        return;
      }

      // Call Firebase Function to defer subscription
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('deferGoogleSubscription');

      final result = await callable.call({
        'packageName': _packageName,
        'subscriptionId': SubscriptionConfig.androidSubscriptionId,
        'purchaseToken': _purchaseToken,
        'deferralInfo': {
          'expectedExpiryTimeMillis':
              _googleExpiryDate
                  ?.add(Duration(days: deferralDays))
                  .millisecondsSinceEpoch,
          'desiredExpiryTimeMillis':
              _googleExpiryDate
                  ?.add(Duration(days: deferralDays))
                  .millisecondsSinceEpoch,
        },
        'userId': _auth.currentUser?.uid,
      });

      if (result.data['success'] == true) {
        // Update local expiry date
        _googleExpiryDate = _googleExpiryDate?.add(
          Duration(days: deferralDays),
        );
        await _saveGoogleSubscriptionData();

        AppLogger.log('Google subscription deferred successfully');

        Get.snackbar(
          'Subscription Deferred',
          'Your subscription has been extended by $deferralDays days.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.secondary,
          colorText: Get.theme.colorScheme.onSecondary,
        );
      } else {
        AppLogger.log(
          'Failed to defer Google subscription: ${result.data['error']}',
        );
      }
    } catch (e) {
      AppLogger.log('Error deferring Google subscription: $e');
    }
  }

  /// Clear Google subscription data
  Future<void> clearGoogleSubscriptionData() async {
    try {
      await _storage.remove(_googlePurchaseTokenKey);
      await _storage.remove(_googleOrderIdKey);
      await _storage.remove(_googlePackageNameKey);
      await _storage.remove(_googleAcknowledgedKey);

      _purchaseToken = null;
      _orderId = null;
      _packageName = null;
      _isGoogleSubscriptionActive = false;
      _isAcknowledged = false;
      _googleExpiryDate = null;
      _googleStartDate = null;

      AppLogger.log('Google subscription data cleared');
    } catch (e) {
      AppLogger.log('Error clearing Google subscription data: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    AppLogger.log('Disposing Google Subscription Service');
  }
}
