import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../controller/subscription_controller.dart';
import '../../utils/custom_color.dart';
import '../../utils/custom_style.dart';
import '../../utils/dimensions.dart';
import '../../widgets/subscription_status_widget.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SubscriptionController>();
    return GetBuilder<SubscriptionController>(
      builder:
          (_) => Scaffold(
            backgroundColor: CustomColor.screenBGColor,
            appBar: AppBar(
              title: Text(
                'Premium Subscription',
                style: CustomStyle.commonTextTitleWhite,
              ),
              backgroundColor: CustomColor.primaryColor,
              elevation: 0,
              leading: IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: CustomColor.primaryTextColor,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: () => controller.refreshData(),
                  icon: const Icon(
                    Icons.refresh,
                    color: CustomColor.primaryTextColor,
                  ),
                ),
              ],
            ),
            body: Obx(
              () =>
                  controller.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _bodyWidget(context, controller),
            ),
          ),
    );
  }

  SingleChildScrollView _bodyWidget(
    BuildContext context,
    SubscriptionController controller,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width - (Dimensions.defaultPaddingSize * 2),
        ),
        child: Column(
          children: [
            _subscriptionStatusWidget(controller),
            SizedBox(height: Dimensions.heightSize * 2),
            if (controller.hasActiveSubscription) ...[
              _currentPlanWidget(controller),
              SizedBox(height: Dimensions.heightSize * 2),
              _paymentMethodsWidget(controller),
              SizedBox(height: Dimensions.heightSize * 2),
              _subscriptionHistoryWidget(controller),
            ] else ...[
              _noSubscriptionWidget(controller),
            ],
          ],
        ),
      ),
    );
  }

  Widget _subscriptionStatusWidget(SubscriptionController controller) {
    return SubscriptionStatusWidget(
      builder: (hasActive) {
        Color statusColor;
        String statusTitle;
        String statusSubtitle;
        IconData statusIcon;
        
        if (hasActive) {
          statusColor = Colors.green;
          statusTitle = 'Premium Active';
          statusSubtitle = 'Enjoying all premium features';
          statusIcon = Icons.verified;
        } else {
          statusColor = Colors.orange;
          statusTitle = 'Free Plan';
          statusSubtitle = 'Upgrade to unlock premium features';
          statusIcon = Icons.info_outline;
        }
        
        return Container(
          padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                statusColor.withValues(alpha: 0.2),
                statusColor.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(Dimensions.radius * 2),
            border: Border.all(
              color: statusColor,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(Dimensions.defaultPaddingSize * 0.4),
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  statusIcon,
                  color: CustomColor.primaryTextColor,
                  size: 24.r,
                ),
              ),
              SizedBox(width: Dimensions.widthSize * 1.5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: CustomStyle.commonTextTitle.copyWith(
                        color: statusColor,
                        fontSize: Dimensions.largeTextSize,
                      ),
                    ),
                    SizedBox(height: Dimensions.heightSize * 0.3),
                    Text(
                      statusSubtitle,
                      style: CustomStyle.commonSubTextTitle,
                    ),
                  ],
                ),
              ),
              if (hasActive)
                Icon(Icons.workspace_premium, color: Colors.green, size: 28.r),
            ],
          ),
        );
      },
    );
  }

  Widget _currentPlanWidget(SubscriptionController controller) {
    final subscription = controller.subscriptions.firstWhereOrNull(
      (sub) => sub['status'] == 'active' || sub['status'] == 'trialing',
    );

    if (subscription == null) return const SizedBox();

    return Container(
      padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
      decoration: BoxDecoration(
        color: CustomColor.surfaceColor,
        borderRadius: BorderRadius.circular(Dimensions.radius * 2),
        border: Border.all(
          color: CustomColor.primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.workspace_premium,
                    color: CustomColor.primaryColor,
                    size: 24.r,
                  ),
                  SizedBox(width: Dimensions.widthSize * 0.5),
                  Text(
                    'Premium Plan',
                    style: CustomStyle.commonTextTitle.copyWith(
                      fontSize: Dimensions.largeTextSize,
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'cancel') {
                    _showCancelDialog(subscription['id']);
                  }
                },
                itemBuilder:
                    (context) => [
                      const PopupMenuItem(
                        value: 'cancel',
                        child: Text('Cancel Subscription'),
                      ),
                    ],
                child: Icon(
                  Icons.more_vert,
                  color: CustomColor.secondaryTextColor,
                ),
              ),
            ],
          ),
          SizedBox(height: Dimensions.heightSize),

          Container(
            padding: EdgeInsets.all(Dimensions.defaultPaddingSize * 0.8),
            decoration: BoxDecoration(
              color: CustomColor.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Dimensions.radius),
            ),
            child: Row(
              children: [
                Text(
                  '\$1.99',
                  style: CustomStyle.commonLargeTextTitleWhite.copyWith(
                    color: CustomColor.primaryColor,
                    fontSize: 24.sp,
                  ),
                ),
                Text(
                  '/month',
                  style: CustomStyle.commonSubTextTitle.copyWith(
                    fontSize: Dimensions.defaultTextSize,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Dimensions.defaultPaddingSize * 0.5,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: CustomColor.primaryColor,
                    borderRadius: BorderRadius.circular(
                      Dimensions.radius * 0.5,
                    ),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: CustomColor.primaryTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: Dimensions.heightSize),
          if (subscription['current_period_end'] != null) ...[
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16.r,
                  color: CustomColor.secondaryTextColor,
                ),
                SizedBox(width: Dimensions.widthSize * 0.5),
                Text(
                  'Next billing: ${DateFormat('MMM dd, yyyy').format(DateTime.fromMillisecondsSinceEpoch(subscription['current_period_end'] * 1000))}',
                  style: CustomStyle.commonSubTextTitle,
                ),
              ],
            ),
          ],

          SizedBox(height: Dimensions.heightSize * 1.5),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showCancelDialog(subscription['id']),
              icon: Icon(Icons.cancel_outlined, size: 18.r, color: Colors.red),
              label: Text(
                'Cancel Subscription',
                style: CustomStyle.commonTextTitle.copyWith(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Dimensions.radius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Container _paymentMethodsWidget(SubscriptionController controller) {
    return Container(
      padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
      decoration: BoxDecoration(
        color: CustomColor.surfaceColor,
        borderRadius: BorderRadius.circular(Dimensions.radius * 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payment Methods', style: CustomStyle.commonTextTitle),
              TextButton(
                onPressed: () => controller.addPaymentMethod(),
                child: Text('Add New', style: CustomStyle.commonTextTitle),
              ),
            ],
          ),
          SizedBox(height: Dimensions.heightSize),
          if (controller.paymentMethods.isEmpty) ...[
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.credit_card_off,
                    size: 48.r,
                    color: CustomColor.secondaryTextColor,
                  ),
                  SizedBox(height: Dimensions.heightSize),
                  Text(
                    'No payment methods added',
                    style: CustomStyle.commonSubTextTitle,
                  ),
                ],
              ),
            ),
          ] else ...[
            ...controller.paymentMethods.map(
              (method) => Container(
                margin: EdgeInsets.only(bottom: Dimensions.heightSize * 0.5),
                padding: EdgeInsets.all(Dimensions.defaultPaddingSize * 0.6),
                decoration: BoxDecoration(
                  border: Border.all(color: CustomColor.outlineColor),
                  borderRadius: BorderRadius.circular(Dimensions.radius),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.credit_card,
                      color: CustomColor.primaryColor,
                      size: 24.r,
                    ),
                    SizedBox(width: Dimensions.widthSize),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '•••• •••• •••• ${method['last4'] ?? '****'}',
                            style: CustomStyle.commonTextTitle,
                          ),
                          Text(
                            '${method['brand']?.toString().capitalizeFirst ?? 'Card'} • Expires ${method['exp_month']}/${method['exp_year']}',
                            style: CustomStyle.commonSubTextTitle,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed:
                          () => controller.deletePaymentMethod(method['id']),
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20.r,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Add pending session indicator
          Obx(() {
            if (controller.hasActivePendingSession) {
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.pending, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment in Progress',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'If you completed payment in Play Store, tap "Check Payment Status" to refresh.',
                      style: TextStyle(color: Colors.orange.shade700),
                    ),
                    SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        controller.handlePlayStoreReturn();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Check Payment Status'),
                    ),
                  ],
                ),
              );
            }
            return SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Container _subscriptionHistoryWidget(SubscriptionController controller) {
    return Container(
      padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
      decoration: BoxDecoration(
        color: CustomColor.surfaceColor,
        borderRadius: BorderRadius.circular(Dimensions.radius * 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Subscription History', style: CustomStyle.commonTextTitle),
          SizedBox(height: Dimensions.heightSize),
          if (controller.subscriptions.isEmpty) ...[
            Center(
              child: Text(
                'No subscription history',
                style: CustomStyle.commonSubTextTitle,
              ),
            ),
          ] else ...[
            ...controller.subscriptions
                .take(5)
                .map(
                  (subscription) => Container(
                    margin: EdgeInsets.only(
                      bottom: Dimensions.heightSize * 0.5,
                    ),
                    padding: EdgeInsets.all(
                      Dimensions.defaultPaddingSize * 0.6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: CustomColor.outlineColor),
                      borderRadius: BorderRadius.circular(Dimensions.radius),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8.w,
                          height: 8.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getStatusColor(subscription['status']),
                          ),
                        ),
                        SizedBox(width: Dimensions.widthSize),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subscription['status']
                                        ?.toString()
                                        .capitalizeFirst ??
                                    'Unknown',
                                style: CustomStyle.commonTextTitle,
                              ),
                              if (subscription['created'] != null) ...[
                                Text(
                                  DateFormat('MMM dd, yyyy').format(
                                    DateTime.fromMillisecondsSinceEpoch(
                                      subscription['created'] * 1000,
                                    ),
                                  ),
                                  style: CustomStyle.commonSubTextTitle,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Container _noSubscriptionWidget(SubscriptionController controller) {
    final plan = controller.singlePlan;
    final isLoading = controller.isLoading;

    return Container(
      padding: EdgeInsets.all(Dimensions.defaultPaddingSize * 1.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CustomColor.primaryColor.withValues(alpha: 0.1),
            CustomColor.secondaryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(Dimensions.radius * 2),
        border: Border.all(
          color: CustomColor.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            size: 80.r,
            color: CustomColor.primaryColor,
          ),
          SizedBox(height: Dimensions.heightSize * 2),
          Text(
            plan?['name'] ?? 'Super Payments',
            style: CustomStyle.commonLargeTextTitleWhite.copyWith(
              fontSize: Dimensions.largeTextSize + 2,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Dimensions.heightSize),
          Text(
            plan?['description'] ??
                'Get Coupons, Brand Deals and Discounts on various brands',
            style: CustomStyle.commonSubTextTitle,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Dimensions.heightSize),
          Text(
            '\$${plan?['price'] ?? 1.99}/${plan?['interval'] ?? 'month'}',
            style: CustomStyle.commonTextTitle.copyWith(
              fontSize: Dimensions.largeTextSize,
              color: CustomColor.primaryColor,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Dimensions.heightSize * 2),

          // Feature list
          if (plan?['features'] != null) ...[
            Container(
              padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(Dimensions.radius),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'What you get:',
                    style: CustomStyle.commonTextTitle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: Dimensions.heightSize),
                  ...List.generate(
                    (plan!['features'] as List).length.clamp(0, 4),
                    (index) => Padding(
                      padding: EdgeInsets.only(
                        bottom: Dimensions.heightSize * 0.5,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16.r,
                          ),
                          SizedBox(width: Dimensions.widthSize),
                          Expanded(
                            child: Text(
                              plan['features'][index],
                              style: CustomStyle.commonSubTextTitle.copyWith(
                                fontSize: Dimensions.smallTextSize,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: Dimensions.heightSize * 2),
          ],

          // Payment options - Google Pay and Apple Pay ONLY
          if (!isLoading) ...[
            // Google Pay button (Android)
            if (controller.googlePayAvailable) ...[
              _buildGooglePayButton(controller, plan),
              SizedBox(height: Dimensions.heightSize),
            ],

            // Apple Pay button (iOS)
            if (controller.applePayAvailable) ...[
              _buildApplePayButton(controller, plan),
              SizedBox(height: Dimensions.heightSize),
            ],

            // No payment method available message
            if (!controller.googlePayAvailable &&
                !controller.applePayAvailable) ...[
              Container(
                padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Dimensions.radius),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.payment_outlined,
                      color: Colors.orange,
                      size: 32.r,
                    ),
                    SizedBox(height: Dimensions.heightSize),
                    Text(
                      'Payment Not Available',
                      style: CustomStyle.commonTextTitle.copyWith(
                        color: Colors.orange,
                      ),
                    ),
                    SizedBox(height: Dimensions.heightSize * 0.5),
                    Text(
                      'Google Pay or Apple Pay is required for subscriptions. Please ensure you have a payment method set up in your device settings.',
                      style: CustomStyle.commonSubTextTitle,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            // Loading state
            Container(
              height: 50.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: CustomColor.primaryColor.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(Dimensions.radius),
              ),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ],

          SizedBox(height: Dimensions.heightSize),
          Text(
            'Secure payments powered by Moov.io',
            style: CustomStyle.commonSubTextTitle.copyWith(
              fontSize: Dimensions.smallTextSize - 2,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGooglePayButton(
    SubscriptionController controller,
    Map<String, dynamic>? plan,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: ElevatedButton(
        onPressed: () => controller.processGooglePaySubscription(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Dimensions.radius),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/google_pay_logo.png',
              height: 24.h,
              width: 24.w,
              errorBuilder:
                  (context, error, stackTrace) =>
                      Icon(Icons.payment, color: Colors.white, size: 24.r),
            ),
            SizedBox(width: Dimensions.widthSize),
            Flexible(
              child: Text(
                'Pay with Google Pay',
                style: CustomStyle.commonTextTitle.copyWith(
                  color: Colors.white,
                  fontSize: Dimensions.mediumTextSize,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplePayButton(
    SubscriptionController controller,
    Map<String, dynamic>? plan,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: ElevatedButton(
        onPressed: () => controller.processApplePaySubscription(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Dimensions.radius),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apple, color: Colors.white, size: 24.r),
            SizedBox(width: Dimensions.widthSize),
            Flexible(
              child: Text(
                'Pay with Apple Pay',
                style: CustomStyle.commonTextTitle.copyWith(
                  color: Colors.white,
                  fontSize: Dimensions.mediumTextSize,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'trialing':
        return Colors.blue;
      case 'canceled':
        return Colors.red;
      case 'incomplete':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _showCancelDialog(String subscriptionId) {
    Get.dialog(
      AlertDialog(
        title: const Text('Cancel Premium Subscription'),
        content: const Text(
          'Are you sure you want to cancel your premium subscription? You will lose access to premium features at the end of your current billing period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Keep Premium'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.find<SubscriptionController>().cancelSubscription(
                subscriptionId,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }
}
