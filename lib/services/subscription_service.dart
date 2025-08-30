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
import 'firebase_cache_service.dart';
import 'subscription_fallback_service.dart';
import 'subscription_error_handler.dart';

/// Custom exception for subscription-related errors
class SubscriptionException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  SubscriptionException(this.message, {this.code, this.originalError});

  @override
  String toString() =>
      'SubscriptionException: $message${code != null ? ' (Code: $code)' : ''}';
}

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final GetStorage _storage = GetStorage();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SubscriptionFallbackService _fallbackService = SubscriptionFallbackService();
  final SubscriptionErrorHandler _errorHandler = SubscriptionErrorHandler();

  // Use centralized subscription configuration
  static Set<String> get _productIds => SubscriptionConfig.allProductIds;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _hasActiveSubscription = false;
  DateTime? _subscriptionExpiry;
  DateTime? _lastValidationTime;

  // Stream controller for subscription status changes
  final StreamController<bool> _subscriptionStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get subscriptionStatusStream =>
      _subscriptionStatusController.stream;

  // Storage keys
  static const String _subscriptionStatusKey = 'subscription_status';
  static const String _lastCheckKey = 'last_subscription_check';
  static const String _subscriptionKey = 'has_active_subscription';
  static const String _subscriptionExpiryKey = 'subscription_expiry';
  static const String _lastValidationKey = 'last_validation';
  static const String _validationHashKey = 'validation_hash';

  // Validation intervals
  static const Duration _validationInterval = Duration(hours: 24);
  static const Duration _expiryCheckInterval = Duration(minutes: 30);
  
  // Grace period configuration
  static const Duration _gracePeriodDuration = Duration(days: 3);
  static const String _gracePeriodStartKey = 'grace_period_start';
  static const String _gracePeriodNotifiedKey = 'grace_period_notified';
  
  // Timer for periodic expiry checking
  Timer? _expiryCheckTimer;
  
  // Grace period state
  DateTime? _gracePeriodStart;
  bool _isInGracePeriod = false;
  bool _gracePeriodNotified = false;

  // Getters
  bool get isAvailable => _isAvailable;
  bool get hasActiveSubscription => _hasActiveSubscription || _isInGracePeriod;
  bool get hasActiveSubscriptionWithoutGrace => _hasActiveSubscription;
  bool get isInGracePeriod => _isInGracePeriod;
  DateTime? get gracePeriodEnd => _gracePeriodStart?.add(_gracePeriodDuration);
  List<ProductDetails> get products => _products;

  /// Initialize the subscription service with comprehensive error handling
  Future<void> initialize() async {
    int retryCount = 0;
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    AppLogger.log('Initializing subscription service...');

    while (retryCount < maxRetries) {
      try {
        _isAvailable = await _inAppPurchase.isAvailable();

        if (_isAvailable) {
          await _loadProductsWithRetry();
          await _checkExistingPurchases();
          _listenToPurchaseUpdates();
        } else {
          AppLogger.log(
            'WARNING: In-app purchases not available on this device',
          );
          _handleInitializationError('In-app purchases not available');
        }

        // Initialize fallback service
        await _fallbackService.initialize();
        
        // Initialize error handler
        await _errorHandler.initialize();
        
        // Load cached subscription status
        _loadSubscriptionStatus();
        
        // Start periodic expiry checking if subscription is active
        _schedulePeriodicExpiryCheck();
        
        AppLogger.log(
          'Subscription service initialized successfully. Available: $_isAvailable, Active: $_hasActiveSubscription',
        );
        return;
      } catch (e, stackTrace) {
        retryCount++;
        AppLogger.log(
          'ERROR: Subscription service initialization failed (attempt $retryCount/$maxRetries): $e',
        );
        AppLogger.log('Stack trace: $stackTrace');

        // Handle error with comprehensive error handler
        await _errorHandler.handleSubscriptionError(
          errorType: 'initialization_error',
          errorMessage: e.toString(),
          context: {
            'attempt': retryCount,
            'maxRetries': maxRetries,
            'stackTrace': stackTrace.toString(),
          },
        );

        if (retryCount >= maxRetries) {
          AppLogger.log(
            'CRITICAL: Failed to initialize subscription service after $maxRetries attempts',
          );
          _isAvailable = false;
          _handleInitializationError(
            'Failed to initialize subscription service',
          );
          return;
        }

        // Wait before retrying
        await Future.delayed(retryDelay);
      }
    }
  }

  /// Load available subscription products with retry mechanism
  Future<void> _loadProductsWithRetry({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        AppLogger.log('Loading products (attempt $attempt/$maxRetries)...');

        final ProductDetailsResponse response = await _inAppPurchase
            .queryProductDetails(_productIds);

        if (response.error != null) {
          final errorMsg =
              'Product query error: ${response.error!.code} - ${response.error!.message}';
          AppLogger.log('ERROR: $errorMsg');

          if (attempt == maxRetries) {
            throw SubscriptionException(
              'Failed to load subscription products after $maxRetries attempts',
              code: 'PRODUCT_LOAD_FAILED',
              originalError: response.error,
            );
          }

          // Wait before retry
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }

        if (response.notFoundIDs.isNotEmpty) {
          AppLogger.log('WARNING: Products not found: ${response.notFoundIDs}');

          if (response.productDetails.isEmpty) {
            final errorMsg =
                'No subscription products are configured. Please contact support.';
            AppLogger.log('ERROR: $errorMsg');

            if (attempt == maxRetries) {
              throw SubscriptionException(
                'No subscription products available',
                code: 'NO_PRODUCTS_FOUND',
              );
            }

            await Future.delayed(Duration(seconds: attempt * 2));
            continue;
          }
        }

        _products = response.productDetails;
        AppLogger.log(
          'Successfully loaded ${_products.length} subscription products',
        );

        // Validate product details
        for (final product in _products) {
          if (product.price.isEmpty) {
            AppLogger.log(
              'WARNING: Product ${product.id} has no price information',
            );
          }
        }
        return;
      } catch (e) {
        AppLogger.log('ERROR: Product loading attempt $attempt failed: $e');

        if (attempt == maxRetries) {
          throw SubscriptionException(
            'Failed to load products after $maxRetries attempts',
            code: 'PRODUCT_LOAD_FAILED',
            originalError: e,
          );
        }

        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  /// Handle initialization errors
  void _handleInitializationError(String message) {
    AppLogger.log('ERROR: Handling initialization error: $message');

    // Show user-friendly error message for production
    Get.snackbar(
      'Premium Features',
      'Premium features require an active subscription. Please check your connection and try again.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Get.theme.colorScheme.primary,
      colorText: Get.theme.colorScheme.onPrimary,
      duration: const Duration(seconds: 4),
    );
  }

  /// Check for existing purchases and verify subscription status
  Future<void> _checkExistingPurchases() async {
    try {
      await _inAppPurchase.restorePurchases();

      // The purchase stream will handle the restored purchases
      // Update last check timestamp
      _storage.write(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      AppLogger.log('Error checking existing purchases: $e');
    }
  }

  /// Listen to purchase updates
  void _listenToPurchaseUpdates() {
    _subscription = _inAppPurchase.purchaseStream.listen(
      (List<PurchaseDetails> purchaseDetailsList) {
        _handlePurchaseUpdates(purchaseDetailsList);
      },
      onDone: () {
        _subscription?.cancel();
      },
      onError: (error) {
        AppLogger.log('Purchase stream error: $error');
      },
    );
  }

  /// Handle purchase updates
  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Handle pending purchase
        AppLogger.log('Purchase pending: ${purchaseDetails.productID}');

        Get.snackbar(
          'Processing Payment',
          'Your payment is being processed. Please wait...',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.secondary,
          colorText: Get.theme.colorScheme.onSecondary,
          duration: const Duration(seconds: 2),
        );
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          // Handle purchase error
          AppLogger.log('Purchase error: ${purchaseDetails.error}');

          Get.snackbar(
            'Payment Failed',
            purchaseDetails.error?.message ??
                'An error occurred during payment. Please try again.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Get.theme.colorScheme.error,
            colorText: Get.theme.colorScheme.onError,
            duration: const Duration(seconds: 4),
          );
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          // Verify and handle successful purchase
          await _handleSuccessfulPurchase(purchaseDetails);
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          AppLogger.log('Purchase canceled: ${purchaseDetails.productID}');

          Get.snackbar(
            'Payment Canceled',
            'Payment was canceled. You can try again anytime.',
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 2),
          );
        }

        // Complete the purchase
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  /// Handle successful purchase
  Future<void> _handleSuccessfulPurchase(
    PurchaseDetails purchaseDetails,
  ) async {
    if (_productIds.contains(purchaseDetails.productID)) {
      // Verify purchase with server-side validation
      if (await _verifyPurchase(purchaseDetails)) {
        final wasSubscribed = _hasActiveSubscription;
        _hasActiveSubscription = true;

        // Set expiry date (30 days from now for monthly subscription)
        _subscriptionExpiry = DateTime.now().add(const Duration(days: 30));
        
        // Clear grace period if user was in one
        if (_isInGracePeriod) {
          _clearGracePeriod();
        }

        // Save to secure storage
        _saveSubscriptionStatus();

        // Also save to legacy storage for compatibility
        _storage.write(_subscriptionStatusKey, true);
        _storage.write(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

        // Invalidate Firebase cache to ensure immediate access
        final user = _auth.currentUser;
        if (user != null) {
          final cacheService = Get.find<FirebaseCacheService>();
          await cacheService.invalidateCache('subscription_${user.uid}');
          await cacheService.invalidateCache('active_subscription_${user.uid}');
          AppLogger.log(
            'Invalidated subscription cache after successful purchase',
          );
        }

        AppLogger.log(
          'Subscription activated with secure storage: ${purchaseDetails.productID}',
        );

        // Schedule periodic expiry checking for new subscription
        _schedulePeriodicExpiryCheck();
        
        // Notify listeners of subscription status change
        if (!wasSubscribed) {
          _subscriptionStatusController.add(true);

          // Show success message
          Get.snackbar(
            'Premium Activated!',
            'Welcome to Premium! Enjoy all the exclusive features.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Get.theme.primaryColor,
            colorText: Get.theme.colorScheme.onPrimary,
            duration: const Duration(seconds: 3),
          );
        }
      }
    }
  }

  /// Verify purchase with server-side validation for production security
  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        AppLogger.log('No authenticated user for purchase verification');
        return false;
      }

      // Get receipt data and purchase token based on platform
      String receiptData = '';
      String? purchaseToken;
      String? packageName;

      if (io.Platform.isIOS) {
        receiptData = purchaseDetails.verificationData.serverVerificationData;
      } else {
        // For Android, get purchase token from verification data
        receiptData = purchaseDetails.verificationData.localVerificationData;
        
        // Extract purchase token from Android verification data
        try {
          final verificationData = jsonDecode(receiptData);
          purchaseToken = verificationData['purchaseToken'] ?? purchaseDetails.purchaseID;
          packageName = verificationData['packageName'] ?? 'com.yourapp.package';
        } catch (e) {
          AppLogger.log('Error parsing Android verification data: $e');
          purchaseToken = purchaseDetails.purchaseID;
          packageName = 'com.yourapp.package';
        }
      }

      if (receiptData.isEmpty && purchaseToken == null) {
        AppLogger.log('No receipt data or purchase token available for verification');
        return false;
      }

      // Validate with Firebase Functions
      final validationResult =
          await PurchaseValidationService.validatePurchaseWithServer(
            receiptData: receiptData,
            productId: purchaseDetails.productID,
            userId: user.uid,
            platform: io.Platform.isIOS ? 'ios' : 'android',
            purchaseToken: purchaseToken,
            packageName: packageName,
          );

      if (validationResult.isValid) {
        AppLogger.log(
          'Purchase verification successful for: ${purchaseDetails.productID}',
        );
        
        // Update local subscription status with validated data
        if (validationResult.expiryDate != null) {
          _subscriptionExpiry = validationResult.expiryDate!;
          _hasActiveSubscription = true;
          _lastValidationTime = DateTime.now();
          
          _saveSubscriptionStatus();
          _subscriptionStatusController.add(true);
        }
        
        return true;
      } else {
        AppLogger.log(
          'Purchase verification failed: ${validationResult.errorMessage}',
        );
        return false;
      }
    } catch (e) {
      AppLogger.log('Error during purchase verification: $e');
      return false;
    }
  }

  /// Purchase a subscription with comprehensive error handling
  Future<bool> purchaseSubscription(String productId) async {
    try {
      AppLogger.log('Starting purchase process for product: $productId');

      // Pre-purchase validations
      if (!_isAvailable) {
        AppLogger.log('In-app purchases not available');
        _showErrorMessage(
          'Service Unavailable',
          'In-app purchases are not available on this device. Please check your device settings.',
        );
        return false;
      }

      if (_products.isEmpty) {
        AppLogger.log('No products available');
        _showErrorMessage(
          'Service Unavailable',
          'Subscription products are not available. Please try again later or contact support.',
        );
        return false;
      }

      final ProductDetails? productDetails =
          _products.where((product) => product.id == productId).firstOrNull;

      if (productDetails == null) {
        AppLogger.log('Product not found: $productId');
        _showErrorMessage(
          'Product Unavailable',
          'The selected subscription plan is not available. Please try refreshing the app.',
        );
        return false;
      }

      // Check if user is already subscribed
      if (await isUserSubscribed()) {
        AppLogger.log('User already has active subscription');
        _showErrorMessage(
          'Already Subscribed',
          'You already have an active premium subscription.',
        );
        return false;
      }

      // Check network connectivity
      if (!await _hasNetworkConnection()) {
        AppLogger.log('No network connection available');
        _showErrorMessage(
          'No Internet',
          'Please check your internet connection and try again.',
        );
        return false;
      }

      AppLogger.log(
        'All validations passed, initiating purchase for product: $productId',
      );

      // Show loading indicator
      Get.snackbar(
        'Processing',
        'Initiating purchase...',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.secondary,
        colorText: Get.theme.colorScheme.onSecondary,
        duration: const Duration(seconds: 2),
      );

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
      );

      final bool success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!success) {
        AppLogger.log('Purchase initiation failed for: $productId');
        _showErrorMessage(
          'Purchase Failed',
          'Unable to start the purchase process. Please try again or contact support.',
        );
      } else {
        AppLogger.log('Purchase initiated successfully for: $productId');
      }

      return success;
    } catch (e) {
      AppLogger.log('Error purchasing subscription: $e');

      // Determine error type for comprehensive handling
      String errorType = 'payment_error';
      if (e.toString().contains('user_cancelled') || e.toString().contains('UserCancel')) {
        errorType = 'user_cancelled';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorType = 'network_error';
      } else if (e.toString().contains('billing_unavailable') || e.toString().contains('BillingUnavailable')) {
        errorType = 'service_unavailable';
      } else if (e.toString().contains('timeout')) {
        errorType = 'timeout_error';
      }

      // Handle error with comprehensive error handler
      final handled = await _errorHandler.handleSubscriptionError(
        errorType: errorType,
        errorMessage: e.toString(),
        context: {
          'productId': productId,
          'userId': _auth.currentUser?.uid,
          'operation': 'purchase_subscription',
          'isAvailable': _isAvailable,
          'productsCount': _products.length,
        },
      );

      // If error handler couldn't resolve the issue, show fallback message
      if (!handled) {
        _showErrorMessage(
          'Purchase Error',
          'Unable to complete purchase. Please try again or contact support.',
        );
      }

      return false;
    }
  }

  /// Check if user is subscribed with direct backend validation
  Future<bool> isUserSubscribed({bool forceRefresh = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _hasActiveSubscription = false;
        _storage.write(_subscriptionStatusKey, false);
        return false;
      }

      // Always check with backend for accurate status
      if (forceRefresh || shouldCheckSubscription()) {
        await _validateSubscriptionWithBackend();
      }

      return _hasActiveSubscription;
    } catch (e) {
      AppLogger.log('Error checking subscription status: $e');

      // Handle error with comprehensive error handler
      final user = _auth.currentUser;
      final handled = await _errorHandler.handleSubscriptionError(
        errorType: 'validation_error',
        errorMessage: e.toString(),
        context: {
          'userId': user?.uid,
          'operation': 'check_subscription_status',
          'forceRefresh': forceRefresh,
          'hasActiveSubscription': _hasActiveSubscription,
          'subscriptionExpiry': _subscriptionExpiry?.millisecondsSinceEpoch,
          'lastValidationTime': _lastValidationTime?.millisecondsSinceEpoch,
        },
      );

      if (handled) {
        AppLogger.log('Error handler resolved subscription validation issue');
        return _hasActiveSubscription;
      }

      // Try comprehensive fallback strategies
      if (user != null) {
        final lastKnownData = {
          'hasActiveSubscription': _hasActiveSubscription,
          'subscriptionExpiry': _subscriptionExpiry?.millisecondsSinceEpoch,
          'lastValidationTime': _lastValidationTime?.millisecondsSinceEpoch,
        };
        
        final fallbackSuccess = await _fallbackService.handleValidationFailure(
          failureReason: e.toString(),
          userId: user.uid,
          lastKnownSubscriptionData: lastKnownData,
        );
        
        if (fallbackSuccess) {
          AppLogger.log('Fallback validation successful in isUserSubscribed');
          return true;
        }
      }

      // Final fallback to local storage
      final localStatus = _storage.read(_subscriptionStatusKey) ?? false;
      AppLogger.log('Using local fallback subscription status: $localStatus');

      return localStatus;
    }
  }

  /// Validate subscription with backend and platform
  Future<void> _validateSubscriptionWithBackend() async {
    try {
      AppLogger.log('Validating subscription with backend...');

      // First check with platform (Apple/Google)
      if (_isAvailable) {
        await _checkExistingPurchases();
      }

      // Then validate with Firebase backend
      final user = _auth.currentUser;
      if (user != null) {
        await _verifySubscriptionWithFirebase(user.uid);
      }

      // Update last check timestamp
      _storage.write(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

      AppLogger.log(
        'Subscription validation completed: $_hasActiveSubscription',
      );
    } catch (e) {
      AppLogger.log('Backend validation failed: $e');
      
      // Handle error with comprehensive error handler
      final user = _auth.currentUser;
      final handled = await _errorHandler.handleSubscriptionError(
        errorType: 'validation_error',
        errorMessage: e.toString(),
        context: {
          'userId': user?.uid,
          'operation': 'backend_validation',
          'hasActiveSubscription': _hasActiveSubscription,
          'subscriptionExpiry': _subscriptionExpiry?.millisecondsSinceEpoch,
          'lastValidationTime': _lastValidationTime?.millisecondsSinceEpoch,
        },
      );

      if (handled) {
        AppLogger.log('Error handler resolved backend validation issue');
        return;
      }
      
      // Try fallback strategies before giving up
      if (user != null) {
        final lastKnownData = {
          'hasActiveSubscription': _hasActiveSubscription,
          'subscriptionExpiry': _subscriptionExpiry?.millisecondsSinceEpoch,
          'lastValidationTime': _lastValidationTime?.millisecondsSinceEpoch,
        };
        
        final fallbackSuccess = await _fallbackService.handleValidationFailure(
          failureReason: e.toString(),
          userId: user.uid,
          lastKnownSubscriptionData: lastKnownData,
        );
        
        if (fallbackSuccess) {
          AppLogger.log('Fallback validation successful');
          // Update subscription status based on fallback result
          _hasActiveSubscription = true;
          _saveSubscriptionStatus();
          return;
        }
      }
      
      rethrow;
    }
  }

  /// Verify subscription status with Firebase
  Future<void> _verifySubscriptionWithFirebase(String userId) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'checkSubscriptionStatus',
      );
      final result = await callable.call({
        'userId': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final data = result.data as Map<String, dynamic>;
      final isActive = data['isSubscribed'] ?? false;
      final expiryDateString = data['expiryDate'];

      _hasActiveSubscription = isActive;

      if (expiryDateString != null) {
        _subscriptionExpiry = DateTime.parse(expiryDateString);
      }

      // CRITICAL FIX: Use _saveSubscriptionStatus() to ensure proper storage
      _saveSubscriptionStatus();

      AppLogger.log('Firebase validation result: $isActive, saved to storage');
    } catch (e) {
      AppLogger.log('Firebase validation failed: $e');
      
      // Handle error with comprehensive error handler
      await _errorHandler.handleSubscriptionError(
        errorType: 'validation_error',
        errorMessage: e.toString(),
        context: {
          'userId': userId,
          'operation': 'firebase_validation',
          'hasActiveSubscription': _hasActiveSubscription,
          'subscriptionExpiry': _subscriptionExpiry?.millisecondsSinceEpoch,
        },
      );
      
      // Don't throw here, let platform validation be the fallback
    }
  }

  /// Check if subscription check is needed (simplified)
  bool shouldCheckSubscription() {
    final int? lastCheck = _storage.read(_lastCheckKey);
    if (lastCheck == null) return true;

    final DateTime lastCheckDate = DateTime.fromMillisecondsSinceEpoch(
      lastCheck,
    );
    final DateTime now = DateTime.now();

    // Simple rule: check every 30 minutes for responsive UI
    return now.difference(lastCheckDate).inMinutes >= 30;
  }

  /// Get subscription status from cache
  bool getCachedSubscriptionStatus() {
    return _storage.read(_subscriptionStatusKey) ?? false;
  }

  /// Check if user has emergency access
  bool hasEmergencyAccess() {
    return _fallbackService.hasEmergencyAccess();
  }

  /// Check if user is in offline grace period
  bool isInOfflineGracePeriod() {
    return _fallbackService.isInOfflineGracePeriod();
  }

  /// Get comprehensive fallback status
  Map<String, dynamic> getFallbackStatus() {
    return _fallbackService.getFallbackStatus();
  }

  /// Store platform receipt for fallback validation
  void storePlatformReceipt(Map<String, dynamic> receiptData) {
    _fallbackService.storePlatformReceipt(receiptData);
  }

  /// Load subscription status from storage with security validation
  void _loadSubscriptionStatus() {
    try {
      // Load encrypted subscription data
      final encryptedData = _storage.read(_subscriptionKey);
      final storedHash = _storage.read(_validationHashKey);

      if (encryptedData != null && storedHash != null) {
        // Verify data integrity
        final currentHash = _generateValidationHash(encryptedData.toString());
        if (currentHash == storedHash) {
          _hasActiveSubscription =
              _decryptSubscriptionData(encryptedData) ?? false;
        } else {
          AppLogger.log(
            'Subscription data integrity check failed, resetting status',
          );
          _hasActiveSubscription = false;
          _clearSubscriptionData();
        }
      } else {
        _hasActiveSubscription = _storage.read(_subscriptionStatusKey) ?? false;
      }

      final expiryTimestamp = _storage.read(_subscriptionExpiryKey);
      if (expiryTimestamp != null) {
        _subscriptionExpiry = DateTime.fromMillisecondsSinceEpoch(
          expiryTimestamp,
        );

        // Check if subscription has expired
        if (_subscriptionExpiry != null &&
            DateTime.now().isAfter(_subscriptionExpiry!)) {
          _hasActiveSubscription = false;
          _saveSubscriptionStatus();
          AppLogger.log('Subscription expired, status updated');
        }
      }

      final lastValidation = _storage.read(_lastValidationKey);
      if (lastValidation != null) {
        _lastValidationTime = DateTime.fromMillisecondsSinceEpoch(
          lastValidation,
        );
      }
      
      // Load grace period state
      final gracePeriodStartTimestamp = _storage.read(_gracePeriodStartKey);
      if (gracePeriodStartTimestamp != null) {
        _gracePeriodStart = DateTime.fromMillisecondsSinceEpoch(
          gracePeriodStartTimestamp,
        );
        
        // Check if still in grace period
        final gracePeriodEnd = _gracePeriodStart!.add(_gracePeriodDuration);
        _isInGracePeriod = DateTime.now().isBefore(gracePeriodEnd);
        
        // If grace period has ended, clear it
        if (!_isInGracePeriod) {
          _clearGracePeriod();
        }
      }
      
      // Load grace period notification state
      _gracePeriodNotified = _storage.read(_gracePeriodNotifiedKey) ?? false;

      // Schedule periodic validation and expiry checking if subscription is active
        if (_hasActiveSubscription) {
          _schedulePeriodicValidation();
          _schedulePeriodicExpiryCheck();
        }

      AppLogger.log('Subscription status loaded: $_hasActiveSubscription');
    } catch (e) {
      AppLogger.log('Error loading subscription status: $e');
      _hasActiveSubscription = false;
      _clearSubscriptionData();
    }
  }

  /// Save subscription status to storage with encryption
  void _saveSubscriptionStatus() {
    try {
      // Encrypt and save subscription data
      final encryptedData = _encryptSubscriptionData(_hasActiveSubscription);
      final validationHash = _generateValidationHash(encryptedData.toString());

      _storage.write(_subscriptionKey, encryptedData);
      _storage.write(_validationHashKey, validationHash);

      // CRITICAL FIX: Always save to the key that getCachedSubscriptionStatus() reads from
      _storage.write(_subscriptionStatusKey, _hasActiveSubscription);

      if (_subscriptionExpiry != null) {
        _storage.write(
          _subscriptionExpiryKey,
          _subscriptionExpiry!.millisecondsSinceEpoch,
        );
      }
      _storage.write(_lastValidationKey, DateTime.now().millisecondsSinceEpoch);
      
      // Save grace period state
      if (_gracePeriodStart != null) {
        _storage.write(_gracePeriodStartKey, _gracePeriodStart!.millisecondsSinceEpoch);
      } else {
        _storage.remove(_gracePeriodStartKey);
      }
      _storage.write(_gracePeriodNotifiedKey, _gracePeriodNotified);

      AppLogger.log(
        'Subscription status saved securely: $_hasActiveSubscription, Grace period: $_isInGracePeriod',
      );
    } catch (e) {
      AppLogger.log('Error saving subscription status: $e');
      // Fallback to unencrypted storage
      _storage.write(_subscriptionStatusKey, _hasActiveSubscription);
    }
  }

  /// Generate validation hash for data integrity
  String _generateValidationHash(String data) {
    // Simple hash generation - in production, use a proper cryptographic hash
    return data.hashCode.toString();
  }

  /// Encrypt subscription data
  String _encryptSubscriptionData(bool status) {
    // Simple encryption - in production, use proper encryption
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${status ? 1 : 0}_$timestamp';
  }

  /// Decrypt subscription data
  bool? _decryptSubscriptionData(String encryptedData) {
    try {
      final parts = encryptedData.split('_');
      if (parts.length >= 2) {
        return parts[0] == '1';
      }
      return null;
    } catch (e) {
      AppLogger.log('Error decrypting subscription data: $e');
      return null;
    }
  }

  /// Clear subscription data
  void _clearSubscriptionData() {
    _storage.remove(_subscriptionKey);
    _storage.remove(_validationHashKey);
    _storage.remove(_subscriptionExpiryKey);
    _storage.remove(_lastValidationKey);
    // CRITICAL FIX: Also clear the key that getCachedSubscriptionStatus() reads from
    _storage.remove(_subscriptionStatusKey);
  }

  /// Schedule periodic validation
  void _schedulePeriodicValidation() {
    if (_lastValidationTime != null) {
      final timeSinceLastValidation = DateTime.now().difference(
        _lastValidationTime!,
      );
      if (timeSinceLastValidation > _validationInterval) {
        // Schedule validation
        Future.delayed(const Duration(seconds: 5), () {
          _validateSubscriptionWithBackend();
        });
      }
    }
  }

  /// Clear subscription status (for testing or logout)
  void clearSubscriptionStatus() {
    _hasActiveSubscription = false;
    _storage.remove(_subscriptionStatusKey);
    _storage.remove(_lastCheckKey);
    _clearSubscriptionData();
  }

  /// Get product by ID
  ProductDetails? getProductById(String productId) {
    return _products.where((product) => product.id == productId).firstOrNull;
  }

  /// Check for subscription expiration with comprehensive validation
  Future<void> checkSubscriptionExpiration() async {
    try {
      AppLogger.log('Checking subscription expiration...');
      
      // Check grace period expiry first
      if (_isInGracePeriod && _gracePeriodStart != null) {
        final gracePeriodEnd = _gracePeriodStart!.add(_gracePeriodDuration);
        
        if (DateTime.now().isAfter(gracePeriodEnd)) {
          AppLogger.log('Grace period expired at: $gracePeriodEnd');
          _clearGracePeriod();
          _subscriptionStatusController.add(false);
          _showSubscriptionExpiredNotification();
          return;
        } else if (isGracePeriodExpiringSoon) {
          _showGracePeriodExpiryWarning();
        }
      }
      
      if (_hasActiveSubscription) {
        // Check local expiry first for immediate response
        if (_subscriptionExpiry != null && DateTime.now().isAfter(_subscriptionExpiry!)) {
          AppLogger.log('Local subscription expired at: $_subscriptionExpiry');
          await _handleSubscriptionExpiry();
          return;
        }
        
        // Validate with backend for accuracy
        await _validateSubscriptionWithBackend();

        // Double-check after backend validation
        if (!_hasActiveSubscription) {
          await _handleSubscriptionExpiry();
        }
      }
    } catch (e) {
      AppLogger.log('Error checking subscription expiration: $e');
    }
  }
  
  /// Handle subscription expiry with grace period management
  Future<void> _handleSubscriptionExpiry() async {
    final wasSubscribed = _hasActiveSubscription;
    _hasActiveSubscription = false;
    _subscriptionExpiry = null;
    
    // Start grace period if not already in one
    if (!_isInGracePeriod && wasSubscribed) {
      _startGracePeriod();
    }
    
    // Save updated status
    _saveSubscriptionStatus();
    
    // Notify listeners - subscription status includes grace period
    _subscriptionStatusController.add(hasActiveSubscription);
    
    // Clear Firebase cache
    final user = _auth.currentUser;
    if (user != null) {
      final cacheService = Get.find<FirebaseCacheService>();
      await cacheService.invalidateCache('subscription_${user.uid}');
      await cacheService.invalidateCache('active_subscription_${user.uid}');
    }
    
    AppLogger.log('Subscription expiry handled with grace period management');
   }
   
   /// Start grace period when subscription expires
   void _startGracePeriod() {
     _gracePeriodStart = DateTime.now();
     _isInGracePeriod = true;
     _gracePeriodNotified = false; // Reset notification flag for new grace period
     
     // Save grace period state
     _storage.write(_gracePeriodStartKey, _gracePeriodStart!.millisecondsSinceEpoch);
     _storage.write(_gracePeriodNotifiedKey, false);
     
     AppLogger.log('Grace period started: $_gracePeriodStart');
     
     // Show grace period notification
     _showGracePeriodNotification();
   }
   
   /// Clear grace period state
   void _clearGracePeriod() {
     _gracePeriodStart = null;
     _isInGracePeriod = false;
     _gracePeriodNotified = false;
     
     // Clear grace period storage
     _storage.remove(_gracePeriodStartKey);
     _storage.remove(_gracePeriodNotifiedKey);
     
     AppLogger.log('Grace period cleared');
   }
   
   /// Check if grace period is about to expire (within 24 hours)
   bool get isGracePeriodExpiringSoon {
     if (!_isInGracePeriod || _gracePeriodStart == null) return false;
     
     final gracePeriodEnd = _gracePeriodStart!.add(_gracePeriodDuration);
     final timeUntilExpiry = gracePeriodEnd.difference(DateTime.now());
     
     return timeUntilExpiry.inHours <= 24;
   }
   
   /// Show grace period notification
   void _showGracePeriodNotification() {
     if (_gracePeriodNotified) return;
     
     final gracePeriodEnd = _gracePeriodStart?.add(_gracePeriodDuration);
     final daysLeft = gracePeriodEnd?.difference(DateTime.now()).inDays ?? 0;
     
     Get.snackbar(
       'Subscription Expired - Grace Period Active',
       'Your subscription has expired but you have $daysLeft days of grace period remaining. Renew now to avoid losing access.',
       snackPosition: SnackPosition.TOP,
       backgroundColor: Get.theme.colorScheme.tertiary,
       colorText: Get.theme.colorScheme.onTertiary,
       duration: const Duration(seconds: 6),
       isDismissible: true,
       mainButton: TextButton(
         onPressed: () {
           Get.back();
           Get.toNamed('/subscription');
         },
         child: Text(
           'Renew Now',
           style: TextStyle(color: Get.theme.colorScheme.onTertiary),
         ),
       ),
     );
     
     _gracePeriodNotified = true;
     _saveSubscriptionStatus();
   }
   
   /// Show grace period expiry warning
   void _showGracePeriodExpiryWarning() {
     final hasNotified = _storage.read(_gracePeriodNotifiedKey) ?? false;
     if (hasNotified) return;
     
     final gracePeriodEnd = _gracePeriodStart?.add(_gracePeriodDuration);
     final hoursLeft = gracePeriodEnd?.difference(DateTime.now()).inHours ?? 0;
     
     Get.snackbar(
       'Grace Period Ending Soon',
       'Your grace period expires in $hoursLeft hours. Renew your subscription now to avoid losing access to premium features.',
       snackPosition: SnackPosition.TOP,
       backgroundColor: Get.theme.colorScheme.error,
       colorText: Get.theme.colorScheme.onError,
       duration: const Duration(seconds: 8),
       isDismissible: true,
       mainButton: TextButton(
         onPressed: () {
           Get.back();
           Get.toNamed('/subscription');
         },
         child: Text(
           'Renew Now',
           style: TextStyle(color: Get.theme.colorScheme.onError),
         ),
       ),
     );
     
     // Mark as notified
     _storage.write(_gracePeriodNotifiedKey, true);
   }

   /// Schedule periodic expiry checking
   void _schedulePeriodicExpiryCheck() {
     _expiryCheckTimer?.cancel();
     
     if (_hasActiveSubscription) {
       _expiryCheckTimer = Timer.periodic(_expiryCheckInterval, (timer) {
         checkSubscriptionExpiration();
       });
       AppLogger.log('Scheduled periodic expiry checking every ${_expiryCheckInterval.inMinutes} minutes');
     }
   }
   

   
   /// Show subscription expired notification
  void _showSubscriptionExpiredNotification() {
    Get.snackbar(
      'Subscription Expired',
      'Your premium subscription has expired. Renew to continue enjoying premium features.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Get.theme.colorScheme.error,
      colorText: Get.theme.colorScheme.onError,
      duration: const Duration(seconds: 5),
      isDismissible: true,
      mainButton: TextButton(
        onPressed: () {
          Get.back();
          // Navigate to subscription screen
          Get.toNamed('/subscription');
        },
        child: Text(
          'Renew',
          style: TextStyle(color: Get.theme.colorScheme.onError),
        ),
      ),
    );
  }

  /// Get available products
  List<ProductDetails> get availableProducts => List.unmodifiable(_products);

  /// Show user-friendly error message
  void _showErrorMessage(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Get.theme.colorScheme.error,
      colorText: Get.theme.colorScheme.onError,
      duration: const Duration(seconds: 4),
    );
  }

  /// Network connectivity check
  Future<bool> _hasNetworkConnection() async {
    try {
      // Basic HTTP connectivity check
      final result = await io.InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        AppLogger.log('Network connectivity confirmed');
        return true;
      }
      AppLogger.log('Network connectivity check failed - no valid addresses');
      return false;
    } catch (e) {
      AppLogger.log('Network check failed: $e');
      
      // Handle network error with error handler
      await _errorHandler.handleSubscriptionError(
        errorType: 'network_error',
        errorMessage: e.toString(),
        context: {
          'operation': 'network_connectivity_check',
        },
      );
      
      return false;
    }
  }

  /// Handle service degradation gracefully
  Future<void> handleServiceDegradation() async {
    try {
      // Attempt to reinitialize service
      await initialize();
    } catch (e) {
      AppLogger.log('Service degradation handling failed: $e');
      
      // Handle service degradation error with error handler
      await _errorHandler.handleSubscriptionError(
        errorType: 'service_unavailable',
        errorMessage: e.toString(),
        context: {
          'operation': 'service_degradation_handling',
        },
      );

      // Inform user about limited functionality
      Get.snackbar(
        'Limited Functionality',
        'Some premium features may be temporarily unavailable.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.secondary,
        colorText: Get.theme.colorScheme.onSecondary,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// Validate platform payment (Apple Pay/Google Pay)
  Future<void> validatePlatformPayment({
    required String paymentMethodId,
    required String transactionId,
    required double amount,
    required String currency,
  }) async {
    try {
      AppLogger.log('Validating platform payment: $transactionId');

      // Call Firebase Function to validate payment
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('validatePlatformPayment');

      final result = await callable.call({
        'paymentMethodId': paymentMethodId,
        'transactionId': transactionId,
        'amount': amount,
        'currency': currency,
        'userId': _auth.currentUser?.uid,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (result.data['success'] == true) {
        // Update subscription status
        _hasActiveSubscription = true;
        _subscriptionExpiry = DateTime.now().add(const Duration(days: 30));
        _lastValidationTime = DateTime.now();

        _saveSubscriptionStatus();
        _subscriptionStatusController.add(true);

        // Invalidate Firebase cache to ensure immediate access
        final user = _auth.currentUser;
        if (user != null) {
          final cacheService = Get.find<FirebaseCacheService>();
          await cacheService.invalidateCache('subscription_${user.uid}');
          await cacheService.invalidateCache('active_subscription_${user.uid}');
          AppLogger.log(
            'Invalidated subscription cache after platform payment validation',
          );
        }

        AppLogger.log('Platform payment validated successfully');
      } else {
        throw SubscriptionException(
          'Payment validation failed: ${result.data['error'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      AppLogger.log('Error validating platform payment: $e');
      
      // Handle platform payment validation error with error handler
      await _errorHandler.handleSubscriptionError(
        errorType: 'payment_error',
        errorMessage: e.toString(),
        context: {
          'paymentMethodId': paymentMethodId,
          'transactionId': transactionId,
          'amount': amount,
          'currency': currency,
          'userId': _auth.currentUser?.uid,
          'operation': 'platform_payment_validation',
        },
      );

      throw SubscriptionException('Failed to validate payment: $e');
    }
  }

  /// Dispose of the subscription service and clean up resources
  void dispose() {
    _subscription?.cancel();
    _expiryCheckTimer?.cancel();
    _subscriptionStatusController.close();
    _fallbackService.dispose();
    AppLogger.log('Subscription service disposed');
  }
}

/// Extension to safely get first element or null
extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}
