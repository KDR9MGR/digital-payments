import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/custom_color.dart';
import '../utils/custom_style.dart';
import '../utils/dimensions.dart';
import '../routes/routes.dart';
import '../screens/paywall_screen.dart';
import '../controller/subscription_controller.dart';
import '../services/platform_payment_service.dart';

class GoPremiumWidget extends StatelessWidget {
  final bool showCloseButton;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry? margin;
  final bool isCompact;

  const GoPremiumWidget({
    super.key,
    this.showCloseButton = false,
    this.onClose,
    this.margin,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? EdgeInsets.all(Dimensions.marginSize),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CustomColor.primaryColor.withOpacity(0.1),
            CustomColor.primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Dimensions.radius),
        border: Border.all(
          color: CustomColor.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(
              isCompact ? 12.0 : Dimensions.defaultPaddingSize,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: CustomColor.primaryColor,
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: Icon(
                        Icons.star,
                        color: Colors.white,
                        size: isCompact ? 16 : 20,
                      ),
                    ),
                    SizedBox(width: 12.0),
                    Expanded(
                      child: Text(
                        'Go Premium',
                        style:
                            isCompact
                                ? CustomStyle.commonTextTitle.copyWith(
                                  color: CustomColor.primaryColor,
                                  fontWeight: FontWeight.w600,
                                )
                                : CustomStyle.commonTextTitle.copyWith(
                                  color: CustomColor.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                      ),
                    ),
                  ],
                ),
                if (!isCompact) ...[
                  SizedBox(height: 12.0),
                  Text(
                    'Unlock premium features for just \$1.99/month',
                    style: CustomStyle.commonTextTitle.copyWith(
                      color: CustomColor.primaryTextColor.withOpacity(0.8),
                    ),
                  ),
                  SizedBox(height: 8.0),
                  _buildFeatureList(),
                ],
                SizedBox(height: isCompact ? 8.0 : 16.0),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          // Platform payment button (Apple Pay/Google Pay)
                          FutureBuilder<bool>(
                            future:
                                Theme.of(context).platform == TargetPlatform.iOS
                                    ? PlatformPaymentService.isApplePayAvailable()
                                    : PlatformPaymentService.isGooglePayAvailable(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data == true) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child:
                                      PlatformPaymentService.getPlatformPaymentButton(
                                        onPressed: _handleDirectPayment,
                                        amount: 1.99,
                                        currency: 'USD',
                                      ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          // Regular subscription button
                          ElevatedButton(
                            onPressed: () => _navigateToSubscription(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CustomColor.primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                vertical: isCompact ? 8 : 12,
                                horizontal: 16.0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6.0),
                              ),
                              elevation: 3,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.lock_open,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  isCompact
                                      ? 'View All Plans'
                                      : 'View All Plans',
                                  style: CustomStyle.commonTextTitle.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isCompact) ...[
                      SizedBox(width: 12.0),
                      TextButton(
                        onPressed: () => _showFeatureDetails(context),
                        child: Text(
                          'Learn More',
                          style: CustomStyle.commonSubTextTitle.copyWith(
                            color: CustomColor.primaryColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (showCloseButton)
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                onPressed: onClose,
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: CustomColor.primaryTextColor.withOpacity(0.6),
                ),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureList() {
    final features = [
      'Unlimited transactions',
      'Priority customer support',
      'Advanced analytics',
      'No transaction fees',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          features
              .map(
                (feature) => Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: CustomColor.primaryColor,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: CustomStyle.commonSubTextTitle.copyWith(
                            color: CustomColor.primaryTextColor.withOpacity(
                              0.7,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }

  void _navigateToSubscription() {
    Get.to(() => const PaywallScreen());
  }

  Future<void> _handleDirectPayment() async {
    // Check if user already has active subscription
    final subscriptionController = Get.find<SubscriptionController>();
    if (subscriptionController.hasActiveSubscription) {
      Get.snackbar(
        'Already Premium',
        'You already have an active premium subscription',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      return;
    }

    // Always redirect to paywall screen for payment processing
    _navigateToSubscription();
  }

  void _showFeatureDetails(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Premium Features',
              style: CustomStyle.commonLargeTextTitleWhite.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrade to Premium for just \$1.99/month and enjoy:',
                  style: CustomStyle.commonTextTitle,
                ),
                SizedBox(height: 16.0),
                _buildDetailedFeatureList(),
                SizedBox(height: Dimensions.marginSize),
                Container(
                  padding: EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: CustomColor.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security,
                        color: CustomColor.primaryColor,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Secure payments via Google Play Store and Apple Pay only',
                          style: CustomStyle.commonSubTextTitle.copyWith(
                            color: CustomColor.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _navigateToSubscription();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColor.primaryColor,
                  elevation: 3,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_open, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Unlock Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailedFeatureList() {
    final detailedFeatures = [
      {
        'icon': Icons.all_inclusive,
        'title': 'Unlimited Transactions',
        'description': 'Send and receive money without limits',
      },
      {
        'icon': Icons.support_agent,
        'title': 'Priority Support',
        'description': '24/7 dedicated customer support',
      },
      {
        'icon': Icons.analytics,
        'title': 'Advanced Analytics',
        'description': 'Detailed insights and spending reports',
      },
      {
        'icon': Icons.money_off,
        'title': 'No Transaction Fees',
        'description': 'Save money on every transaction',
      },
    ];

    return Column(
      children:
          detailedFeatures
              .map(
                (feature) => Padding(
                  padding: EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: CustomColor.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          feature['icon'] as IconData,
                          color: CustomColor.primaryColor,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feature['title'] as String,
                              style: CustomStyle.commonTextTitle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              feature['description'] as String,
                              style: CustomStyle.commonSubTextTitle.copyWith(
                                color: CustomColor.primaryTextColor.withOpacity(
                                  0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }
}

/// Compact version of the Go Premium widget for smaller spaces
class GoPremiumBanner extends StatelessWidget {
  final VoidCallback? onTap;
  final bool showCloseButton;
  final VoidCallback? onClose;

  const GoPremiumBanner({
    super.key,
    this.onTap,
    this.showCloseButton = true,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => Get.toNamed(Routes.subscriptionScreen),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        padding: EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              CustomColor.primaryColor,
              CustomColor.primaryColor.withOpacity(0.8),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(6.0),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Icon(Icons.lock_open, color: Colors.white, size: 20),
                SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Unlock Premium Features',
                        style: CustomStyle.commonTextTitle.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Just \$1.99/month • Tap to unlock',
                        style: CustomStyle.commonSubTextTitle.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              ],
            ),
            if (showCloseButton)
              Positioned(
                top: -4,
                right: -4,
                child: IconButton(
                  onPressed: onClose,
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 20, minHeight: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
