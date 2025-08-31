import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/stripe_service.dart';
import '../services/moov_service.dart';
import '../services/platform_payment_service.dart';
import '../config/stripe_config.dart';
import '../config/moov_config.dart';
import '../routes/routes.dart';
import 'dart:math';

class SubscriptionController extends GetxController {
  final StripeService _stripeService = StripeService();
  final MoovService _moovService = MoovService();
  
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
  String get singlePlanId => useMoovPayments ? 'super_payments' : 'premium_monthly';
  Map<String, dynamic>? get singlePlan => useMoovPayments 
    ? MoovConfig.subscriptionPlans['super_payments']
    : StripeConfig.subscriptionPlans['premium_monthly'];

  @override
  void onInit() {
    super.onInit();
    // Check platform payment availability immediately (this doesn't require network)
    _checkPlatformPaymentAvailability();
    
    // Delay other initialization to ensure user authentication is ready
    Future.delayed(Duration(milliseconds: 500), () {
      _initializeSubscriptionData();
    });
  }

  // Initialize subscription data
  Future<void> _initializeSubscriptionData() async {
    _isLoading.value = true;
    try {
      print('Initializing subscription data...');
      
      // Only try to load account IDs if user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (useMoovPayments) {
          await _loadMoovAccountId();
        } else {
          await _loadCustomerId();
        }
        
        // These methods should not fail the entire initialization
        try {
          await _checkSubscriptionStatus();
        } catch (e) {
          print('Warning: Could not check subscription status: $e');
        }
        
        try {
          await _loadSubscriptions();
        } catch (e) {
          print('Warning: Could not load subscriptions: $e');
        }
        
        try {
          await _loadPaymentMethods();
        } catch (e) {
          print('Warning: Could not load payment methods: $e');
        }
      } else {
        print('User not authenticated, skipping account initialization');
      }
      
      print('Subscription data initialization completed');
    } catch (e) {
      print('Error during subscription initialization: $e');
      // Don't show error to user - they can still use the app
    } finally {
      _isLoading.value = false;
    }
  }

  // Check platform payment availability
  Future<void> _checkPlatformPaymentAvailability() async {
    try {
      _googlePayAvailable.value = await PlatformPaymentService.isGooglePayAvailable();
      _applePayAvailable.value = await PlatformPaymentService.isApplePayAvailable();
    } catch (e) {
      print('Error checking platform payment availability: $e');
    }
  }

  // Load Moov account ID from Firestore or create new account
  Future<void> _loadMoovAccountId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not authenticated, skipping Moov account creation');
        return;
      }

      // Check if user document exists with Moov account ID
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      if (userDoc.exists && userDoc.data()?['moovAccountId'] != null) {
        _moovAccountId.value = userDoc.data()!['moovAccountId'];
        print('Loaded existing Moov account ID: ${_moovAccountId.value}');
      } else {
        // Try to create new Moov account, but don't fail if it doesn't work
        try {
          await _createMoovAccount(user, userDocRef, userDoc);
        } catch (e) {
          print('Warning: Could not create Moov account: $e');
          // Continue without Moov account - user can still use other features
        }
      }
    } catch (e) {
      print('Error loading Moov account ID: $e');
      // Don't throw error - allow app to continue
    }
  }

  // Separate method to create Moov account
  Future<void> _createMoovAccount(User user, DocumentReference userDocRef, DocumentSnapshot userDoc) async {
    // Get user data for account creation
    String email = user.email ?? 'user@example.com';
    String firstName = 'User';
    String lastName = '';
    
    // If user document exists, get name from there
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData != null) {
        firstName = userData['firstName'] ?? 'User';
        lastName = userData['lastName'] ?? '';
        email = userData['email'] ?? user.email ?? 'user@example.com';
      }
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

    print('Creating Moov account for user: $email');
    
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
      print('Created Moov account: ${_moovAccountId.value}');
      
      // Save account ID to Firestore
      if (userDoc.exists) {
        await userDocRef.update({'moovAccountId': _moovAccountId.value});
      } else {
        // Create new user document if it doesn't exist
        await userDocRef.set({
          'userId': user.uid,
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'moovAccountId': _moovAccountId.value,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
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

      // First check if user document exists, if not create it
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      if (userDoc.exists && userDoc.data()?['stripeCustomerId'] != null) {
        _customerId.value = userDoc.data()!['stripeCustomerId'];
      } else {
        // Get user data for customer creation
        String email = user.email ?? 'user@example.com';
        String name = user.displayName ?? 'User';
        
        // If user document exists, get name from there
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          name = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
          if (name.isEmpty) name = userData['email'] ?? 'User';
          email = userData['email'] ?? user.email ?? 'user@example.com';
        }

        // Create new customer
        final customerId = await _stripeService.createCustomer(
          email: email,
          name: name,
          phone: user.phoneNumber,
        );
        
        if (customerId != null) {
          _customerId.value = customerId;
          // Save customer ID to Firestore
          if (userDoc.exists) {
            await userDocRef.update({'stripeCustomerId': customerId});
          } else {
            // Create new user document if it doesn't exist
            await userDocRef.set({
              'userId': user.uid,
              'email': email,
              'firstName': name.split(' ').first,
              'lastName': name.split(' ').length > 1 ? name.split(' ').sublist(1).join(' ') : '',
              'stripeCustomerId': customerId,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        } else {
          throw Exception('Failed to create Stripe customer');
        }
      }
    } catch (e) {
      print('Error loading customer ID: $e');
      Get.snackbar('Error', 'Failed to initialize payment system. Please try again.');
    }
  }

  // Check subscription status
  Future<void> _checkSubscriptionStatus() async {
    try {
      _hasActiveSubscription.value = await _stripeService.hasActiveSubscription();
      final status = await _stripeService.getSubscriptionStatus();
      _subscriptionStatus.value = status ?? '';
    } catch (e) {
      print('Error checking subscription status: $e');
    }
  }

  // Load user's subscriptions
  Future<void> _loadSubscriptions() async {
    try {
      final subscriptions = await _stripeService.getSubscriptions();
      _subscriptions.value = subscriptions;
      
      // Set current plan from active subscription
      final activeSubscription = subscriptions.firstWhereOrNull(
        (sub) => sub['status'] == 'active' || sub['status'] == 'trialing'
      );
      
      if (activeSubscription != null) {
        _currentPlan.value = _getPlanNameFromPriceId(activeSubscription['price_id']);
      }
    } catch (e) {
      print('Error loading subscriptions: $e');
    }
  }

  // Load payment methods
  Future<void> _loadPaymentMethods() async {
    try {
      final paymentMethods = await _stripeService.getPaymentMethods();
      _paymentMethods.value = paymentMethods;
    } catch (e) {
      print('Error loading payment methods: $e');
    }
  }

  // Get plan name from price ID
  String _getPlanNameFromPriceId(String priceId) {
    for (final entry in StripeConfig.subscriptionPrices.entries) {
      if (entry.value == priceId) {
        return StripeConfig.subscriptionPlans[entry.key]?['name'] ?? 'Premium Plan';
      }
    }
    return 'Premium Plan';
  }

  // Subscribe to the premium plan
  Future<bool> subscribeToPremium() async {
    if (useMoovPayments) {
      return await _subscribeWithMoov();
    } else {
      return await _subscribeWithStripe();
    }
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

        await _initializeSubscriptionData(); // Refresh data
        Get.back(); // Go back to previous screen
        Get.snackbar('Success', 'Welcome to Super Payments! 🎉');
        return true;
      }

      return false;
    } catch (e) {
      print('Error subscribing with Moov: $e');
      Get.snackbar('Error', 'Failed to subscribe: $e');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  // Subscribe with Stripe (fallback)
  Future<bool> _subscribeWithStripe() async {
    if (_customerId.value.isEmpty) {
      Get.snackbar('Error', 'Customer not found');
      return false;
    }

    _isLoading.value = true;
    try {
      final priceId = StripeConfig.subscriptionPrices['premium_monthly'];
      if (priceId == null) {
        Get.snackbar('Error', 'Subscription plan not found');
        return false;
      }

      final success = await _stripeService.presentPaymentSheet(
        customerId: _customerId.value,
        priceId: priceId,
      );

      if (success) {
        await _initializeSubscriptionData(); // Refresh data
        Get.back(); // Go back to previous screen
        Get.snackbar('Success', 'Welcome to Premium! 🎉');
      }

      return success;
    } catch (e) {
      print('Error subscribing with Stripe: $e');
      Get.snackbar('Error', 'Failed to subscribe: $e');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  // Store subscription data in Firestore
  Future<void> _storeSubscriptionData(Map<String, dynamic> subscriptionData) async {
    try {
      await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(subscriptionData['subscriptionId'])
          .set(subscriptionData);
    } catch (e) {
      print('Error storing subscription data: $e');
    }
  }

  // Cancel subscription
  Future<bool> cancelSubscription(String subscriptionId) async {
    _isLoading.value = true;
    try {
      final success = await _stripeService.cancelSubscription(
        subscriptionId: subscriptionId,
      );

      if (success) {
        await _initializeSubscriptionData(); // Refresh data
        Get.snackbar('Success', 'Subscription cancelled successfully');
      }

      return success;
    } catch (e) {
      print('Error cancelling subscription: $e');
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
      final clientSecret = await _stripeService.createSetupIntent(
        customerId: _customerId.value,
      );

      if (clientSecret == null) return false;

      // This would typically open a card input form
      // For now, we'll show a placeholder message
      Get.snackbar('Info', 'Payment method setup initiated');
      
      await _loadPaymentMethods(); // Refresh payment methods
      return true;
    } catch (e) {
      print('Error adding payment method: $e');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  // Delete payment method
  Future<bool> deletePaymentMethod(String paymentMethodId) async {
    _isLoading.value = true;
    try {
      final success = await _stripeService.deletePaymentMethod(
        paymentMethodId: paymentMethodId,
      );

      if (success) {
        await _loadPaymentMethods(); // Refresh payment methods
        Get.snackbar('Success', 'Payment method removed successfully');
      }

      return success;
    } catch (e) {
      print('Error deleting payment method: $e');
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
    if (!_googlePayAvailable.value) {
      Get.snackbar('Error', 'Google Pay is not available on this device');
      return;
    }

    _isLoading.value = true;
    try {
      final plan = singlePlan;
      if (plan == null) {
        Get.snackbar('Error', 'Subscription plan not found');
        return;
      }

      // Generate subscription ID
      final subscriptionId = 'sub_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';

      // Process Google Pay payment
      final paymentResult = await PlatformPaymentService.processGooglePaySubscription(
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
          'paymentMethod': 'google_pay',
          'createdAt': FieldValue.serverTimestamp(),
          'currentPeriodStart': DateTime.now(),
          'currentPeriodEnd': DateTime.now().add(Duration(days: 30)),
        });

        await _initializeSubscriptionData(); // Refresh data
        Get.back(); // Go back to previous screen
        Get.snackbar('Success', 'Welcome to Super Payments! 🎉');
      } else {
        Get.snackbar('Error', 'Google Pay payment failed. Please try again.');
      }
    } catch (e) {
      print('Error processing Google Pay subscription: $e');
      Get.snackbar('Error', 'Failed to process Google Pay payment: $e');
    } finally {
      _isLoading.value = false;
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
      final plan = singlePlan;
      if (plan == null) {
        Get.snackbar('Error', 'Subscription plan not found');
        return;
      }

      // Generate subscription ID
      final subscriptionId = 'sub_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';

      // Process Apple Pay payment
      final paymentResult = await PlatformPaymentService.processApplePaySubscription(
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
          'paymentMethod': 'apple_pay',
          'createdAt': FieldValue.serverTimestamp(),
          'currentPeriodStart': DateTime.now(),
          'currentPeriodEnd': DateTime.now().add(Duration(days: 30)),
        });

        await _initializeSubscriptionData(); // Refresh data
        Get.back(); // Go back to previous screen
        Get.snackbar('Success', 'Welcome to Super Payments! 🎉');
      } else {
        Get.snackbar('Error', 'Apple Pay payment failed. Please try again.');
      }
    } catch (e) {
      print('Error processing Apple Pay subscription: $e');
      Get.snackbar('Error', 'Failed to process Apple Pay payment: $e');
    } finally {
      _isLoading.value = false;
    }
  }
} 