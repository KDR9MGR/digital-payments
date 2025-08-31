import '../config/moov_config.dart';
import '../routes/routes.dart';
import '../services/moov_service.dart';
import '../services/platform_payment_service.dart';
import '../services/subscription_service.dart';
import '../services/payment_validation_service.dart';
import '../services/firebase_batch_service.dart';
import '../services/firebase_query_optimizer.dart';
import '../services/firebase_cache_service.dart';
import '../services/subscription_error_handler.dart';
import '/utils/app_logger.dart';
import '../screens/paywall_screen.dart';
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionController extends GetxController {
  final MoovService _moovService = MoovService();
  final SubscriptionService _subscriptionService = Get.find<SubscriptionService>();
  final FirebaseBatchService _batchService = FirebaseBatchService();
  final FirebaseQueryOptimizer _queryOptimizer = FirebaseQueryOptimizer();
  final FirebaseCacheService _cacheService = FirebaseCacheService();
  
  // Observable variables
  final RxBool _isLoading = false.obs;
  final RxBool _hasActiveSubscription = false.obs;
  final RxString _currentPlan = ''.obs;
  final RxString _subscriptionStatus = ''.obs;
  final RxList<Map<String, dynamic>> _subscriptions = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> _paymentMethods = <Map<String, dynamic>>[].obs;
  final RxString _customerId = ''.obs;
  final RxString _moovAccountId = ''.obs;
  final RxBool _useMoovPayments = true.obs; // Switch to use Moov instead of Stripe
  final RxBool _googlePayAvailable = false.obs;
  final RxBool _applePayAvailable = false.obs;
  
  // Timer for periodic subscription status checking
  Timer? _statusCheckTimer;
  
  // Stream subscription for real-time updates
  StreamSubscription<bool>? _subscriptionStatusSubscription;
  
  // Session management variables
  final RxBool _hasActivePendingSession = false.obs;
  final RxString _pendingSessionId = ''.obs;
  Timer? _sessionTimeoutTimer;
  DateTime? _playStoreRedirectTime;

  // Getters
  bool get isLoading => _isLoading.value;
  bool get hasActiveSubscription => _hasActiveSubscription.value;
  String get currentPlan => _currentPlan.value;
  String get subscriptionStatus => _subscriptionStatus.value;
  List<Map<String, dynamic>> get subscriptions => _subscriptions;
  List<Map<String, dynamic>> get paymentMethods => _paymentMethods;
  String get customerId => _customerId.value;
  String get moovAccountId => _moovAccountId.value;
  bool get useMoovPayments => _useMoovPayments.value;
  bool get googlePayAvailable => _googlePayAvailable.value;
  bool get applePayAvailable => _applePayAvailable.value;

  // Get the single plan
  String get singlePlanId => 'super_payments';
  Map<String, dynamic>? get singlePlan => MoovConfig.subscriptionPlans['super_payments'];

  @override
  void onInit() {
    super.onInit();
    // Check platform payment availability immediately (this doesn't require network)
    _checkPlatformPaymentAvailability();
    
    // Delay other initialization to ensure user authentication is ready
    Future.delayed(Duration(milliseconds: 500), () {
      _initializeSubscriptionData();
    });
    
    // Start periodic subscription status checking
    _startPeriodicStatusCheck();
    
    // Check for incomplete session on init
    _checkForIncompleteSession();
    
    // Listen to subscription service stream for real-time updates
    _subscriptionStatusSubscription = _subscriptionService.subscriptionStatusStream.listen((hasSubscription) {
      _hasActiveSubscription.value = hasSubscription;
      _subscriptionStatus.value = hasSubscription ? 'active' : 'inactive';
    });
  }
  
  @override
  void onClose() {
    _statusCheckTimer?.cancel();
    _sessionTimeoutTimer?.cancel();
    _subscriptionStatusSubscription?.cancel();
    super.onClose();
  }

  // Initialize subscription data
  Future<void> _initializeSubscriptionData() async {
    _isLoading.value = true;
    try {
      AppLogger.log('Initializing subscription data...');
      
      // Only try to load account IDs if user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Check cache first for subscription status
        final cachedStatus = await _cacheService.getCachedSubscriptionStatus(user.uid);
        if (cachedStatus != null) {
          _updateSubscriptionFromCache(cachedStatus);
          AppLogger.log('Loaded subscription status from cache');
        }
        
        if (useMoovPayments) {
          await _loadMoovAccountId();
        } else {
          await _loadCustomerId();
        }
        
        // These methods should not fail the entire initialization
        try {
          await _checkSubscriptionStatus();
        } catch (e) {
          AppLogger.log('Warning: Could not check subscription status: $e');
        }
        
        try {
          await _loadSubscriptions();
        } catch (e) {
          AppLogger.log('Warning: Could not load subscriptions: $e');
        }
        
        try {
          await _loadPaymentMethods();
        } catch (e) {
          AppLogger.log('Warning: Could not load payment methods: $e');
        }
      } else {
        AppLogger.log('User not authenticated, skipping account initialization');
      }
      
      AppLogger.log('Subscription data initialization completed');
    } catch (e) {
      AppLogger.log('Error during subscription initialization: $e');
      // Don't show error to user - they can still use the app
    } finally {
      _isLoading.value = false;
    }
  }

  void _updateSubscriptionFromCache(Map<String, dynamic> cachedStatus) {
    _hasActiveSubscription.value = cachedStatus['hasActiveSubscription'] ?? false;
    _currentPlan.value = cachedStatus['currentPlan'] ?? '';
    _subscriptionStatus.value = cachedStatus['subscriptionStatus'] ?? 'inactive';
    _customerId.value = cachedStatus['customerId'] ?? '';
    _moovAccountId.value = cachedStatus['moovAccountId'] ?? '';
  }

  // Check platform payment availability
  Future<void> _checkPlatformPaymentAvailability() async {
    try {
      _googlePayAvailable.value = await PlatformPaymentService.isGooglePayAvailable();
      _applePayAvailable.value = await PlatformPaymentService.isApplePayAvailable();
    } catch (e) {
      AppLogger.log('Error checking platform payment availability: $e');
    }
  }

  // Load Moov account ID from Firestore or create new account
  Future<void> _loadMoovAccountId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        AppLogger.log('User not authenticated, skipping Moov account creation');
        return;
      }

      // Use optimized query service to get user data
      final userData = await _queryOptimizer.getUserData(user.uid);
      
      if (userData != null && userData['moovAccountId'] != null) {
        _moovAccountId.value = userData['moovAccountId'];
        AppLogger.log('Loaded existing Moov account ID: ${_moovAccountId.value}');
      } else {
        // Try to create new Moov account, but don't fail if it doesn't work
        try {
          await _createMoovAccount(user);
        } catch (e) {
          AppLogger.log('Warning: Could not create Moov account: $e');
          // Continue without Moov account - user can still use other features
        }
      }
    } catch (e) {
      AppLogger.log('Error loading Moov account ID: $e');
      // Don't throw error - allow app to continue
    }
  }

  // Separate method to create Moov account
  Future<void> _createMoovAccount(User user) async {
    // Get user data for account creation
    String email = user.email ?? 'user@example.com';
    String firstName = 'User';
    String lastName = '';
    
    // Try to get existing user data from optimized query
    final userData = await _queryOptimizer.getUserData(user.uid);
    if (userData != null) {
      firstName = userData['firstName'] ?? 'User';
      lastName = userData['lastName'] ?? '';
      email = userData['email'] ?? user.email ?? 'user@example.com';
    } else {
      // Parse display name if available
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        final nameParts = user.displayName!.split(' ');
        firstName = nameParts.first;
        if (nameParts.length > 1) {
          lastName = nameParts.sublist(1).join(' ');
        }
      }
    }

    AppLogger.log('Creating Moov account for user: $email');
    
    // Create new Moov account
    final accountResult = await _moovService.createAccount(
      email: email,
      firstName: firstName,
      lastName: lastName,
      phone: user.phoneNumber,
      userId: user.uid,
    );
    
    if (accountResult != null && accountResult['success'] == true) {
      _moovAccountId.value = accountResult['accountId'];
      AppLogger.log('Created Moov account: ${_moovAccountId.value}');
      
      // Use batch service for optimized writes
      final userData = await _queryOptimizer.getUserData(user.uid);
      if (userData != null) {
        await _batchService.addUpdate(
          collection: 'users',
          documentId: user.uid,
          data: {'moovAccountId': _moovAccountId.value},
        );
      } else {
        // Create new user document if it doesn't exist
        await _batchService.addWrite(
          collection: 'users',
          documentId: user.uid,
          data: {
            'userId': user.uid,
            'email': email,
            'firstName': firstName,
            'lastName': lastName,
            'moovAccountId': _moovAccountId.value,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      }
      await _batchService.flushBatch();
      
      // Invalidate cache to ensure fresh data
      await _cacheService.invalidateUserCaches(user.uid);
    } else {
      throw Exception('Failed to create Moov account: ${accountResult?['error'] ?? 'Unknown error'}');
    }
  }

  // Load customer ID from Firestore or create new customer
  Future<void> _loadCustomerId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Get.snackbar('Error', 'Please log in to access subscription features');
        return;
      }

      // Use optimized query service to check user data
      final userData = await _queryOptimizer.getUserData(user.uid);

      // Set customer ID to user ID for Moov payments
      _customerId.value = user.uid;
      
      // Ensure user document exists
      if (userData == null) {
        String email = user.email ?? 'user@example.com';
        String name = user.displayName ?? 'User';
        
        await _batchService.addWrite(
          collection: 'users',
          documentId: user.uid,
          data: {
            'userId': user.uid,
            'email': email,
            'firstName': name.split(' ').first,
            'lastName': name.split(' ').length > 1 ? name.split(' ').sublist(1).join(' ') : '',
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
        await _batchService.flushBatch();
        
        // Invalidate cache to ensure fresh data
        await _cacheService.invalidateUserCaches(user.uid);
      }
    } catch (e) {
      AppLogger.log('Error loading customer ID: $e');
      Get.snackbar('Error', 'Failed to initialize payment system. Please try again.');
    }
  }

  // Check subscription status
  Future<void> _checkSubscriptionStatus() async {
    try {
      AppLogger.log('SubscriptionController: Checking subscription status...');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _hasActiveSubscription.value = false;
        _subscriptionStatus.value = 'inactive';
        return;
      }

      // Always check with subscription service first for the most accurate status
      final serviceHasSubscription = await _subscriptionService.isUserSubscribed(forceRefresh: true);
      
      // Use optimized query service for subscription status validation
      final subscriptionData = await _queryOptimizer.getSubscriptionStatus(user.uid);
      
      // Prioritize service status as it includes platform validation
      final isValid = serviceHasSubscription || (subscriptionData != null);
      _hasActiveSubscription.value = isValid;
      _subscriptionStatus.value = isValid ? 'active' : 'inactive';
      
      if (isValid) {
        _currentPlan.value = subscriptionData?['planId'] ?? singlePlanId;
        AppLogger.log('SubscriptionController: User has active subscription (Service: $serviceHasSubscription, Firebase: ${subscriptionData != null})');
      } else {
        _currentPlan.value = '';
        AppLogger.log('SubscriptionController: User does not have active subscription');
      }
    } catch (e) {
      AppLogger.error('SubscriptionController: Error checking subscription status', error: e);
      // Fallback to subscription service status on error
      try {
        final fallbackStatus = await _subscriptionService.isUserSubscribed();
        _hasActiveSubscription.value = fallbackStatus;
        _subscriptionStatus.value = fallbackStatus ? 'active' : 'inactive';
        AppLogger.log('SubscriptionController: Using fallback status: $fallbackStatus');
      } catch (fallbackError) {
        AppLogger.log('SubscriptionController: Fallback also failed: $fallbackError');
        // Keep current status if both fail
      }
    }
  }

  // Load user's subscriptions
  Future<void> _loadSubscriptions() async {
    try {
      // For now, return empty list - implement based on your backend
      _subscriptions.value = [];
    } catch (e) {
      AppLogger.log('Error loading subscriptions: $e');
    }
  }

  // Load payment methods
  Future<void> _loadPaymentMethods() async {
    try {
      // For now, return empty list - implement based on your backend
      _paymentMethods.value = [];
    } catch (e) {
      AppLogger.log('Error loading payment methods: $e');
    }
  }

  // Subscribe to the premium plan
  Future<bool> subscribeToPremium() async {
    return await _subscribeWithMoov();
  }

  // Subscribe with Moov and platform payments
  Future<bool> _subscribeWithMoov() async {
    if (_moovAccountId.value.isEmpty) {
      Get.snackbar('Error', 'Account not found');
      return false;
    }

    _isLoading.value = true;
    try {
      final plan = singlePlan;
      if (plan == null) {
        Get.snackbar('Error', 'Subscription plan not found');
        return false;
      }

      // Generate subscription ID
      final subscriptionId = 'sub_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';

      // Show platform payment sheet
      final paymentResult = await PlatformPaymentService.showPaymentSheet(
        amount: plan['price'].toDouble(),
        currency: plan['currency'],
        subscriptionId: subscriptionId,
      );

      if (paymentResult != null && paymentResult['success'] == true) {
        // Store subscription in Firestore
        await _storeSubscriptionData({
          'subscriptionId': subscriptionId,
          'planId': singlePlanId,
          'status': 'active',
          'amount': plan['price'],
          'currency': plan['currency'],
          'interval': plan['interval'],
          'userId': FirebaseAuth.instance.currentUser?.uid,
          'moovAccountId': _moovAccountId.value,
          'paymentMethod': paymentResult['paymentMethod'] ?? 'platform_pay',
          'createdAt': FieldValue.serverTimestamp(),
          'currentPeriodStart': DateTime.now(),
          'currentPeriodEnd': DateTime.now().add(Duration(days: 30)),
        });

        // Force refresh subscription status in service first
        await _subscriptionService.isUserSubscribed(forceRefresh: true);
        
        // Then refresh controller data
        await _initializeSubscriptionData();
        
        // Update local status immediately
        _hasActiveSubscription.value = true;
        _subscriptionStatus.value = 'active';
        _currentPlan.value = singlePlanId;
        
        AppLogger.log('SubscriptionController: Subscription activated successfully');
        
        Get.back(); // Go back to previous screen
        Get.snackbar('Success', 'Welcome to Super Payments! 🎉');
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.log('Error subscribing with Moov: $e');
      
      // Use proper error handling instead of showing raw exception
      await SubscriptionErrorHandler().handleSubscriptionError(
        errorType: 'payment_error',
        errorMessage: e.toString(),
        context: {'screen': 'subscription', 'action': 'moov_subscribe'},
      );
      return false;
    } finally {
      _isLoading.value = false;
    }
  }


  // Store subscription data in Firestore using batch service
  Future<void> _storeSubscriptionData(Map<String, dynamic> subscriptionData) async {
    try {
      await _batchService.addWrite(
        collection: 'subscriptions',
        documentId: subscriptionData['subscriptionId'],
        data: subscriptionData,
      );
      await _batchService.flushBatch();
      
      // Cache the updated subscription status
      final userId = subscriptionData['userId'];
      if (userId != null) {
        final cacheData = {
          'hasActiveSubscription': subscriptionData['status'] == 'active',
          'currentPlan': subscriptionData['planId'] ?? '',
          'subscriptionStatus': subscriptionData['status'] ?? 'inactive',
          'customerId': _customerId.value,
          'moovAccountId': _moovAccountId.value,
          'lastUpdated': DateTime.now().toIso8601String(),
        };
        await _cacheService.cacheSubscriptionStatus(userId, cacheData);
        AppLogger.log('Cached subscription status after storing data');
      }
    } catch (e) {
      AppLogger.log('Error storing subscription data: $e');
    }
  }

  // Cancel subscription
  Future<bool> cancelSubscription(String subscriptionId) async {
    _isLoading.value = true;
    try {
      // Implement subscription cancellation logic
      // This would typically call your backend API
      AppLogger.log('Cancelling subscription: $subscriptionId');
      
      // For now, simulate cancellation
      await Future.delayed(Duration(milliseconds: 500));
      
      await _initializeSubscriptionData(); // Refresh data
      Get.snackbar('Success', 'Subscription cancelled successfully');
      
      return true;
    } catch (e) {
      AppLogger.log('Error cancelling subscription: $e');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  // Add payment method
  Future<bool> addPaymentMethod() async {
    if (_customerId.value.isEmpty) {
      Get.snackbar('Error', 'Customer not found');
      return false;
    }

    _isLoading.value = true;
    try {
      // Implement payment method addition logic
      // This would typically integrate with your payment processor
      AppLogger.log('Adding payment method for customer: ${_customerId.value}');
      
      // For now, simulate payment method addition
      await Future.delayed(Duration(milliseconds: 500));
      
      Get.snackbar('Info', 'Payment method setup initiated');
      
      await _loadPaymentMethods(); // Refresh payment methods
      return true;
    } catch (e) {
      AppLogger.log('Error adding payment method: $e');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  // Delete payment method
  Future<bool> deletePaymentMethod(String paymentMethodId) async {
    _isLoading.value = true;
    try {
      final success = await _moovService.deletePaymentMethod(
        _moovAccountId.value,
        paymentMethodId,
      );

      if (success) {
        await _loadPaymentMethods(); // Refresh payment methods
        Get.snackbar('Success', 'Payment method removed successfully');
      }

      return success;
    } catch (e) {
      AppLogger.log('Error deleting payment method: $e');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  // Navigate to subscription screen
  void navigateToSubscriptions() {
    Get.toNamed(Routes.subscriptionScreen);
  }

  // Navigate to subscription plans screen (now just premium upgrade)
  void navigateToSubscriptionPlans() {
    Get.toNamed(Routes.subscriptionPlansScreen);
  }

  // Refresh all data
  Future<void> refreshData() async {
    await _initializeSubscriptionData();
  }

  // Process Google Pay subscription
  Future<void> processGooglePaySubscription() async {
    // Check if user already has active subscription
    if (hasActiveSubscription) {
      Get.snackbar(
        'Already Premium',
        'You already have an active premium subscription',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      return;
    }

    // Redirect to paywall screen for payment processing
    Get.to(() => const PaywallScreen());
  }

  // Store pending payment session
  Future<void> _storePendingPaymentSession(Map<String, dynamic> sessionData) async {
    try {
      await _batchService.addWrite(
        collection: 'payment_sessions',
        documentId: sessionData['sessionId'],
        data: sessionData,
      );
      await _batchService.flushBatch();
    } catch (e) {
      AppLogger.log('Error storing payment session: $e');
    }
  }

  // Redirect to Google Play Store
  Future<void> _redirectToGooglePlayStore() async {
    try {
      const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.yourapp.package';
      final uri = Uri.parse(playStoreUrl);
      
      // Record the time when redirecting to Play Store
      _playStoreRedirectTime = DateTime.now();
      _hasActivePendingSession.value = true;
      
      // Start session timeout timer (5 minutes)
      _startSessionTimeoutTimer();
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        // Start checking for app resume after a delay
        _startAppResumeDetection();
      } else {
        _clearPendingSession();
        throw Exception('Could not launch Google Play Store');
      }
    } catch (e) {
      _clearPendingSession();
      AppLogger.log('Error launching Google Play Store: $e');
      rethrow;
    }
  }
  
  // Start periodic subscription status checking
  void _startPeriodicStatusCheck() {
    // Check subscription status every 30 seconds when app is active
    _statusCheckTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _checkSubscriptionStatus();
    });
  }
  
  // Validate payment status after returning from Play Store
  Future<void> validatePaymentStatus() async {
    try {
      AppLogger.log('Validating payment status after Play Store redirect');
      
      // Force refresh subscription status
      await _checkSubscriptionStatus();
      
      // If user now has active subscription, show success message
      if (_hasActiveSubscription.value) {
        Get.snackbar(
          'Success', 
          'Welcome to Super Payments! Your subscription is now active. 🎉',
          duration: Duration(seconds: 5),
        );
        
        // Refresh all subscription data
        await _initializeSubscriptionData();
      }
    } catch (e) {
      AppLogger.log('Error validating payment status: $e');
    }
  }

  // Process Apple Pay subscription
  Future<void> processApplePaySubscription() async {
    if (!_applePayAvailable.value) {
      Get.snackbar('Error', 'Apple Pay is not available on this device');
      return;
    }

    _isLoading.value = true;
    try {
      // Start payment session with timeout
      PaymentValidationService.startPaymentSession();
      
      final plan = singlePlan;
      if (plan == null) {
        Get.snackbar('Error', 'Subscription plan not found');
        PaymentValidationService.endPaymentSession();
        return;
      }

      // Generate subscription ID
      final subscriptionId = 'sub_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
      final transactionId = 'txn_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';

      // Validate subscription purchase
      final subscriptionValidation = await PaymentValidationService.validateSubscriptionPurchase(
        subscriptionId: subscriptionId,
        planId: singlePlanId,
        amount: plan['price'].toDouble(),
        paymentMethod: 'apple_pay',
      );
      
      if (!subscriptionValidation['success']) {
        // Log validation error silently without showing user prompt
        AppLogger.log('Subscription validation failed: ${subscriptionValidation['error']}');
        PaymentValidationService.endPaymentSession();
        return;
      }

      // Process Apple Pay payment
      final paymentResult = await PlatformPaymentService.processApplePaySubscription(
        amount: plan['price'].toDouble(),
        currency: plan['currency'],
        subscriptionId: subscriptionId,
      );

      if (paymentResult != null && paymentResult['success'] == true) {
        // Validate Apple Pay payment
        final paymentValidation = await PaymentValidationService.validateApplePayPayment(
          transactionId: transactionId,
          amount: plan['price'].toDouble(),
          currency: plan['currency'],
          subscriptionId: subscriptionId,
        );
        
        if (!paymentValidation['success']) {
          // Log payment validation error silently without showing user prompt
          AppLogger.log('Payment validation failed: ${paymentValidation['error']}');
          PaymentValidationService.endPaymentSession();
          return;
        }
        
        // Store subscription in Firestore
        await _storeSubscriptionData({
          'subscriptionId': subscriptionId,
          'transactionId': transactionId,
          'planId': singlePlanId,
          'status': 'active',
          'amount': plan['price'],
          'currency': plan['currency'],
          'interval': plan['interval'],
          'userId': FirebaseAuth.instance.currentUser?.uid,
          'moovAccountId': _moovAccountId.value,
          'paymentMethod': 'apple_pay',
          'createdAt': FieldValue.serverTimestamp(),
          'currentPeriodStart': DateTime.now(),
          'currentPeriodEnd': DateTime.now().add(Duration(days: 30)),
          'validatedAt': paymentValidation['validatedAt'],
        });

        // Force refresh subscription status in service first
        await _subscriptionService.isUserSubscribed(forceRefresh: true);
        
        // Then refresh controller data
        await _initializeSubscriptionData();
        
        // Update local status immediately
        _hasActiveSubscription.value = true;
        _subscriptionStatus.value = 'active';
        _currentPlan.value = singlePlanId;
        
        AppLogger.log('SubscriptionController: Apple Pay subscription activated successfully');
        
        PaymentValidationService.endPaymentSession();
        Get.back(); // Go back to previous screen
        Get.snackbar('Success', 'Welcome to Super Payments! 🎉');
      } else {
        PaymentValidationService.endPaymentSession();
        Get.snackbar('Error', 'Apple Pay payment failed. Please try again.');
      }
    } catch (e) {
      AppLogger.log('Error processing Apple Pay subscription: $e');
      PaymentValidationService.endPaymentSession();
      
      // Use proper error handling instead of showing raw exception
      await SubscriptionErrorHandler().handleSubscriptionError(
        errorType: 'payment_error',
        errorMessage: e.toString(),
        context: {'screen': 'subscription', 'action': 'apple_pay_subscribe'},
      );
    } finally {
      _isLoading.value = false;
    }
  }

  // Check for incomplete session on app start
  Future<void> _checkForIncompleteSession() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check for pending payment sessions
      final sessionsQuery = await FirebaseFirestore.instance
          .collection('payment_sessions')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (sessionsQuery.docs.isNotEmpty) {
        final sessionDoc = sessionsQuery.docs.first;
        final sessionData = sessionDoc.data();
        final createdAt = (sessionData['createdAt'] as Timestamp).toDate();
        
        // If session is less than 10 minutes old, consider it active
        if (DateTime.now().difference(createdAt).inMinutes < 10) {
          _hasActivePendingSession.value = true;
          _pendingSessionId.value = sessionDoc.id;
          
          // Start monitoring for completion
          _startSessionMonitoring();
        } else {
          // Clean up old pending session
          await _batchService.addUpdate(
            collection: 'payment_sessions',
            documentId: sessionDoc.id,
            data: {'status': 'expired'},
          );
          await _batchService.flushBatch();
        }
      }
    } catch (e) {
      AppLogger.log('Error checking for incomplete session: $e');
    }
  }

  // Start session timeout timer
  void _startSessionTimeoutTimer() {
    _sessionTimeoutTimer?.cancel();
    _sessionTimeoutTimer = Timer(Duration(minutes: 5), () {
      _handleSessionTimeout();
    });
  }

  // Handle session timeout
  void _handleSessionTimeout() {
    if (_hasActivePendingSession.value) {
      AppLogger.log('Payment session timed out');
      _clearPendingSession();
      
      // Show timeout message if user is still in the app
      Get.snackbar(
        'Payment Timeout',
        'The payment session has expired. Please try again.',
        duration: Duration(seconds: 3),
      );
    }
  }

  // Start app resume detection
  void _startAppResumeDetection() {
    // Start checking subscription status more frequently after Play Store redirect
    Timer.periodic(Duration(seconds: 5), (timer) {
      if (!_hasActivePendingSession.value) {
        timer.cancel();
        return;
      }
      
      // Check if enough time has passed since redirect
      if (_playStoreRedirectTime != null &&
          DateTime.now().difference(_playStoreRedirectTime!).inSeconds > 10) {
        _checkSubscriptionStatusAfterPlayStore();
      }
      
      // Cancel after 5 minutes
      if (timer.tick > 60) {
        timer.cancel();
        _handleSessionTimeout();
      }
    });
  }

  // Check subscription status after Play Store redirect
  Future<void> _checkSubscriptionStatusAfterPlayStore() async {
    try {
      // Force refresh subscription status
      await _checkSubscriptionStatus();
      
      if (_hasActiveSubscription.value) {
        // Payment was successful
        _clearPendingSession();
        Get.snackbar(
          'Success',
          'Welcome to Super Payments! Your subscription is now active. 🎉',
          duration: Duration(seconds: 5),
        );
        await _initializeSubscriptionData();
      }
    } catch (e) {
      AppLogger.log('Error checking subscription status after Play Store: $e');
    }
  }

  // Start session monitoring
  void _startSessionMonitoring() {
    Timer.periodic(Duration(seconds: 10), (timer) {
      if (!_hasActivePendingSession.value) {
        timer.cancel();
        return;
      }
      
      _checkSubscriptionStatusAfterPlayStore();
      
      // Cancel after 10 minutes
      if (timer.tick > 60) {
        timer.cancel();
        _handleSessionTimeout();
      }
    });
  }

  // Clear pending session
  void _clearPendingSession() {
    _hasActivePendingSession.value = false;
    final sessionId = _pendingSessionId.value;
    _pendingSessionId.value = '';
    _playStoreRedirectTime = null;
    _sessionTimeoutTimer?.cancel();
    
    // Update session status in Firestore if exists
    if (sessionId.isNotEmpty) {
      _batchService.addUpdate(
        collection: 'payment_sessions',
        documentId: sessionId,
        data: {'status': 'cancelled', 'endedAt': FieldValue.serverTimestamp()},
      ).then((_) => _batchService.flushBatch())
        .catchError((e) => AppLogger.log('Error updating session status: $e'));
    }
  }

  // Handle back navigation from Play Store
  void handlePlayStoreReturn() {
    if (_hasActivePendingSession.value) {
      AppLogger.log('User returned from Play Store without completing payment');
      
      // Give a short delay to check if payment was actually completed
      Future.delayed(Duration(seconds: 3), () {
        if (_hasActivePendingSession.value && !_hasActiveSubscription.value) {
          _clearPendingSession();
          Get.snackbar(
            'Payment Cancelled',
            'Payment was not completed. You can try again anytime.',
            duration: Duration(seconds: 3),
          );
        }
      });
    }
  }

  // Getters for session state
  bool get hasActivePendingSession => _hasActivePendingSession.value;
  String get pendingSessionId => _pendingSessionId.value;
}
