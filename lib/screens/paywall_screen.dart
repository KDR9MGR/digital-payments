import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../config/subscription_config.dart';
import '../services/subscription_service.dart';
import '../utils/app_logger.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final SubscriptionService _subscriptionService = Get.find<SubscriptionService>();
  bool _isLoading = false;
  String? _selectedProductId;
  List<ProductDetails> _products = [];
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadProductsOptimized();
  }

  Future<void> _loadProductsOptimized() async {
    AppLogger.log('PaywallScreen: Starting optimized product loading');
    
    // Check if service is already initialized to avoid redundant initialization
    if (_subscriptionService.isAvailable && _subscriptionService.products.isNotEmpty) {
      AppLogger.log('PaywallScreen: Using cached products from service');
      _products = _subscriptionService.products;
      if (_products.isNotEmpty) {
        _selectedProductId = _products.first.id;
      }
      setState(() {
        _hasInitialized = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      AppLogger.log('PaywallScreen: Initializing subscription service');
      await _subscriptionService.initialize();
      _products = _subscriptionService.products;
      
      AppLogger.log('PaywallScreen: Loaded ${_products.length} products');
      
      if (_products.isNotEmpty) {
        _selectedProductId = _products.first.id;
        AppLogger.log('PaywallScreen: Selected default product: $_selectedProductId');
      } else {
        AppLogger.log('PaywallScreen: No subscription products available');
        _showErrorDialog('Subscription products are not available. Please try again later or contact support.');
      }
    } catch (e) {
      AppLogger.log('PaywallScreen: Error loading products: $e');
      _showErrorDialog('Failed to load subscription options. Please check your connection and try again.');
    } finally {
      setState(() {
        _isLoading = false;
        _hasInitialized = true;
      });
      AppLogger.log('PaywallScreen: Product loading completed. Loading: $_isLoading, Products: ${_products.length}');
    }
  }

  Future<void> _purchaseSubscription() async {
    AppLogger.log('PaywallScreen: Subscribe Now button clicked - starting purchase process');
    AppLogger.log('PaywallScreen: Selected product ID: $_selectedProductId');
    
    if (_selectedProductId == null) {
      AppLogger.log('PaywallScreen: No product selected, showing error');
      _showErrorDialog('Please select a subscription plan.');
      return;
    }

    // Prevent multiple simultaneous purchases
    if (_isLoading) {
      AppLogger.log('PaywallScreen: Purchase already in progress, ignoring');
      return;
    }

    AppLogger.log('PaywallScreen: Setting loading state to true');
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if user already has an active subscription
      final hasActiveSubscription = await _subscriptionService.isUserSubscribed();
      if (hasActiveSubscription) {
        AppLogger.log('PaywallScreen: User already has active subscription');
        _showSuccessDialog('You already have an active subscription!');
        // Navigate back after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Get.back();
        });
        return;
      }

      // Validate network connectivity
      if (!_subscriptionService.isAvailable) {
        AppLogger.log('PaywallScreen: In-app purchases not available');
        _showErrorDialog('In-app purchases are not available. Please check your connection and try again.');
        return;
      }

      AppLogger.log('PaywallScreen: Calling subscription service to purchase: $_selectedProductId');
      final success = await _subscriptionService.purchaseSubscription(_selectedProductId!);
      
      AppLogger.log('PaywallScreen: Purchase result: $success');
      
      if (success) {
        // Purchase initiated successfully
        // Listen for purchase completion
        _listenForPurchaseCompletion();
        AppLogger.log('PaywallScreen: Purchase initiated successfully');
        _showSuccessDialog('Purchase initiated! Please complete the payment in the App Store.');
      } else {
        AppLogger.log('PaywallScreen: Purchase initiation failed');
        _showErrorDialog('Failed to initiate purchase. Please try again or contact support if the issue persists.');
      }
    } on SubscriptionException catch (e) {
      AppLogger.log('PaywallScreen: Subscription error: ${e.message}');
      _showErrorDialog(e.message);
    } catch (e) {
      AppLogger.log('PaywallScreen: Error purchasing subscription: $e');
      _showErrorDialog('An unexpected error occurred during purchase. Please try again.');
    } finally {
      AppLogger.log('PaywallScreen: Setting loading state to false');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _listenForPurchaseCompletion() {
    // Listen to subscription status changes
    _subscriptionService.subscriptionStatusStream.listen((hasSubscription) {
      if (hasSubscription && mounted) {
        AppLogger.log('PaywallScreen: Purchase completed successfully');
        _showSuccessDialog('Subscription activated! Welcome to Premium!');
        // Navigate back after showing success
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Get.back();
        });
      }
    });
  }



  void _showErrorDialog(String message) {
    Get.dialog(
      AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    Get.dialog(
      AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatPrice(ProductDetails product) {
    return product.price;
  }

  String _getProductTitle(ProductDetails product) {
    final plan = SubscriptionConfig.getPlan(product.id);
    return plan?.name ?? product.title;
  }

  String _getProductDescription(ProductDetails product) {
    final plan = SubscriptionConfig.getPlan(product.id);
    return plan?.description ?? product.description;
  }
  
  bool _isProductPopular(ProductDetails product) {
    final plan = SubscriptionConfig.getPlan(product.id);
    return plan?.isPopular ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: Theme.of(context).colorScheme.onSurface,
            size: 28,
          ),
          onPressed: () => Get.back(),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Skip',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: !_hasInitialized
            ? _buildLoadingSkeleton()
            : SingleChildScrollView(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 40.h),
                    
                    // App Icon/Logo
                    Container(
                      width: 120.w,
                      height: 120.w,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                      child: Icon(
                        Icons.payment,
                        size: 60.sp,
                        color: Colors.white,
                      ),
                    ),
                    
                    SizedBox(height: 32.h),
                    
                    // Title
                    Text(
                      'Unlock Premium Features',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: 16.h),
                    
                    // Subtitle
                    Text(
                      'Subscribe to access all premium features and enjoy unlimited transactions',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: 40.h),
                    
                    // Features List
                    _buildFeaturesList(),
                    
                    SizedBox(height: 40.h),
                    
                    // Subscription Plans
                    if (_isLoading) 
                      _buildPlansSkeleton()
                    else if (_products.isNotEmpty)
                      ..._buildSubscriptionPlans()
                    else
                      Container(
                        padding: EdgeInsets.all(20.w),
                        child: Text(
                          'No subscription plans available. Please check your connection and try again.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    
                    SizedBox(height: 32.h),
                    
                    // Purchase Button
                    SizedBox(
                      width: double.infinity,
                      height: 56.h,
                      child: Builder(
                        builder: (context) {
                          final isEnabled = _selectedProductId != null && _products.isNotEmpty && !_isLoading;
                          final buttonText = _isLoading ? 'Processing...' : 'Subscribe Now';
                          
                          AppLogger.log('PaywallScreen: Rendering Subscribe button - Products: ${_products.length}, Selected: $_selectedProductId, Enabled: $isEnabled, Loading: $_isLoading, Text: $buttonText');
                          
                          return ElevatedButton(
                            onPressed: isEnabled
                                ? () {
                                    AppLogger.log('PaywallScreen: Subscribe Now button pressed');
                                    _purchaseSubscription();
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEnabled 
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.primary.withOpacity(0.6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                            ),
                            child: _isLoading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20.w,
                                        height: 20.h,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Text(
                                        buttonText,
                                        style: TextStyle(
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    buttonText,
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                    
                    SizedBox(height: 24.h),
                    
                    // Terms and Privacy
                    Text(
                      'By subscribing, you agree to our Terms of Service and Privacy Policy',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 40.h),
          // App Icon skeleton
          Container(
            width: 120.w,
            height: 120.w,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(24.r),
            ),
          ),
          SizedBox(height: 32.h),
          // Title skeleton
          Container(
            width: 200.w,
            height: 24.h,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
          SizedBox(height: 16.h),
          // Subtitle skeleton
          Container(
            width: 300.w,
            height: 16.h,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
          SizedBox(height: 40.h),
          // Features skeleton
          ...List.generate(6, (index) => Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Row(
              children: [
                Container(
                  width: 24.w,
                  height: 24.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 16.w),
                Container(
                  width: 150.w,
                  height: 16.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ],
            ),
          )),
          SizedBox(height: 40.h),
          _buildPlansSkeleton(),
        ],
      ),
    );
  }

  Widget _buildPlansSkeleton() {
    return Column(
      children: List.generate(2, (index) => Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          children: [
            Container(
              width: 20.w,
              height: 20.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100.w,
                    height: 16.h,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    width: 60.w,
                    height: 14.h,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      )),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      'Unlimited transactions',
      'Advanced analytics',
      'Priority customer support',
      'Export transaction history',
      'Multi-currency support',
      'Ad-free experience',
    ];

    return Column(
      children: features.map((feature) => _buildFeatureItem(feature)).toList(),
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Theme.of(context).colorScheme.primary,
            size: 24.sp,
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              feature,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSubscriptionPlans() {
    if (_products.isEmpty) {
      return [
        Container(
          padding: EdgeInsets.all(20.w),
          child: Text(
            'No subscription plans available. Please check your connection and try again.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }
    
    return _products.map((product) {
      final isSelected = _selectedProductId == product.id;
      
      return GestureDetector(
        onTap: () {
          setState(() {
            _selectedProductId = product.id;
          });
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 16.h),
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withOpacity(0.3),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            children: [
              Radio<String>(
                value: product.id,
                groupValue: _selectedProductId,
                onChanged: (value) {
                  setState(() {
                    _selectedProductId = value;
                  });
                },
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getProductTitle(product),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _getProductDescription(product),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatPrice(product),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}