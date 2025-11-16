import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../controllers/unified_subscription_controller.dart';
import '../../utils/custom_color.dart';
import '../../utils/custom_style.dart';
import '../../utils/dimensions.dart';

class UnifiedSubscriptionScreen extends StatelessWidget {
  const UnifiedSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<UnifiedSubscriptionController>(
      init: UnifiedSubscriptionController(),
      builder:
          (controller) => Scaffold(
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
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              ),
              actions: [
                IconButton(
                  onPressed: () => controller.refreshSubscriptionStatus(),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
              ],
            ),
            body: Obx(
              () =>
                  controller.isLoading.value
                      ? const Center(child: CircularProgressIndicator())
                      : _bodyWidget(context, controller),
            ),
          ),
    );
  }

  SingleChildScrollView _bodyWidget(
    BuildContext context,
    UnifiedSubscriptionController controller,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width -
              (Dimensions.defaultPaddingSize * 2),
        ),
        child: Column(
          children: [
            _subscriptionStatusWidget(controller),
            SizedBox(height: Dimensions.heightSize * 2),
            // _platformInfoWidget(controller), // Hidden as requested
            // SizedBox(height: Dimensions.heightSize * 2),
            if (controller.isSubscriptionActive.value) ...[
              _currentPlanWidget(controller),
              SizedBox(height: Dimensions.heightSize * 2),
              _subscriptionDetailsWidget(controller),
              SizedBox(height: Dimensions.heightSize * 2),
              _managementActionsWidget(controller),
            ] else ...[
              _noSubscriptionWidget(controller),
            ],
          ],
        ),
      ),
    );
  }

  Widget _subscriptionStatusWidget(UnifiedSubscriptionController controller) {
    return Obx(() {
      final bool isActive = controller.isSubscriptionActive.value;
      final bool isExpiringSoon = controller.isSubscriptionExpiringSoon();
      final bool isExpired = controller.isSubscriptionExpired();

      Color statusColor;
      String statusTitle;
      String statusSubtitle;
      IconData statusIcon;

      if (isExpired) {
        statusColor = Colors.red;
        statusTitle = 'Subscription Expired';
        statusSubtitle = 'Please renew to continue using premium features';
        statusIcon = Icons.error;
      } else if (isExpiringSoon) {
        statusColor = Colors.orange;
        statusTitle = 'Expiring Soon';
        statusSubtitle = 'Renews in ${controller.getDaysUntilExpiry()} days';
        statusIcon = Icons.warning;
      } else if (isActive) {
        statusColor = Colors.green;
        statusTitle = 'Premium Active';
        statusSubtitle = 'Enjoying all premium features';
        statusIcon = Icons.verified;
      } else {
        statusColor = Colors.grey;
        statusTitle = 'Free Plan';
        statusSubtitle = 'Upgrade to unlock premium features';
        statusIcon = Icons.info_outline;
      }

      return Container(
        padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(Dimensions.radius),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 40.r),
            SizedBox(width: Dimensions.widthSize),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusTitle,
                    style: CustomStyle.commonTextTitle.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: Dimensions.heightSize * 0.3),
                  Text(statusSubtitle, style: CustomStyle.cardSubtitleStyle),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _currentPlanWidget(UnifiedSubscriptionController controller) {
    final Map<String, dynamic> plan = controller.getSubscriptionPlan();

    return Container(
      padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
      decoration: BoxDecoration(
        color: CustomColor.surfaceColor,
        borderRadius: BorderRadius.circular(Dimensions.radius),
        border: Border.all(
          color: CustomColor.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Plan',
                style: CustomStyle.commonTextTitle.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Dimensions.defaultPaddingSize * 0.5,
                  vertical: Dimensions.defaultPaddingSize * 0.2,
                ),
                decoration: BoxDecoration(
                  color: CustomColor.primaryColor,
                  borderRadius: BorderRadius.circular(Dimensions.radius * 0.5),
                ),
                child: Text(
                  'ACTIVE',
                  style: CustomStyle.cardSubtitleStyle.copyWith(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Dimensions.heightSize),
          Text(
            plan['name'] ?? 'Digital Payments -Premium',
            style: CustomStyle.commonLargeTextTitleWhite.copyWith(
              color: CustomColor.primaryTextColor,
            ),
          ),
          SizedBox(height: Dimensions.heightSize * 0.5),
          Text(
            plan['description'] ?? 'Premium subscription with all features',
            style: CustomStyle.cardSubtitleStyle,
          ),
          SizedBox(height: Dimensions.heightSize),
          Row(
            children: [
              Text(
                plan['price'] ?? '\$1.99',
                style: CustomStyle.commonLargeTextTitleWhite.copyWith(
                  color: CustomColor.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '/${plan['duration']?.toLowerCase() ?? 'month'}',
                style: CustomStyle.cardSubtitleStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _subscriptionDetailsWidget(UnifiedSubscriptionController controller) {
    return Obx(() {
      final Map<String, dynamic> details = controller.subscriptionDetails;
      final DateTime? expiryDate = controller.expiryDate.value;

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
            Text(
              'Subscription Details',
              style: CustomStyle.commonTextTitle.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: Dimensions.heightSize),
            if (expiryDate != null) ...[
              _detailRow(
                'Expires On',
                DateFormat('MMM dd, yyyy').format(expiryDate),
              ),
              SizedBox(height: Dimensions.heightSize * 0.5),
            ],
            if (details['orderId'] != null) ...[
              _detailRow('Order ID', details['orderId']),
              SizedBox(height: Dimensions.heightSize * 0.5),
            ],
            if (details['productId'] != null) ...[
              _detailRow('Product ID', details['productId']),
              SizedBox(height: Dimensions.heightSize * 0.5),
            ],
            _detailRow(
              'Platform',
              controller.currentPlatform.value.toUpperCase(),
            ),
            SizedBox(height: Dimensions.heightSize * 0.5),
            _detailRow(
              'Status',
              controller.subscriptionStatus.value.toUpperCase(),
            ),
          ],
        ),
      );
    });
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: CustomStyle.cardSubtitleStyle),
        Flexible(
          child: Text(
            value,
            style: CustomStyle.commonTextTitle,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _managementActionsWidget(UnifiedSubscriptionController controller) {
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
          Text(
            'Manage Subscription',
            style: CustomStyle.commonTextTitle.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: Dimensions.heightSize),
          Row(
            children: [
              // Restore button removed as requested
              // SizedBox(width: Dimensions.widthSize),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => controller.cancelSubscription(),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noSubscriptionWidget(UnifiedSubscriptionController controller) {
    final Map<String, dynamic> plan = controller.getSubscriptionPlan();

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
            plan['name'] ?? 'Digital Payments -Premium',
            style: CustomStyle.commonLargeTextTitleWhite.copyWith(
              fontSize: Dimensions.largeTextSize + 2,
              color: CustomColor.primaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Dimensions.heightSize),
          Text(
            plan['description'] ??
                'Get premium features and enhanced functionality',
            style: CustomStyle.cardSubtitleStyle,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Dimensions.heightSize * 2),

          // Features list
          if (plan['features'] != null) ...[
            ...List.generate(
              (plan['features'] as List).length,
              (index) => Padding(
                padding: EdgeInsets.symmetric(
                  vertical: Dimensions.heightSize * 0.3,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: CustomColor.primaryColor,
                      size: 20.r,
                    ),
                    SizedBox(width: Dimensions.widthSize),
                    Expanded(
                      child: Text(
                        plan['features'][index],
                        style: CustomStyle.cardSubtitleStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          SizedBox(height: Dimensions.heightSize * 2),

          // Price and subscribe button
          Container(
            padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
            decoration: BoxDecoration(
              color: CustomColor.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Dimensions.radius),
              border: Border.all(
                color: CustomColor.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      plan['price'] ?? '\$1.99',
                      style: CustomStyle.commonLargeTextTitleWhite.copyWith(
                        color: CustomColor.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 28.sp,
                      ),
                    ),
                    Text(
                      '/${plan['duration']?.toLowerCase() ?? 'month'}',
                      style: CustomStyle.cardSubtitleStyle.copyWith(
                        color: CustomColor.primaryColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Dimensions.heightSize),
                Obx(
                  () => ElevatedButton(
                    onPressed:
                        controller.isLoading.value
                            ? null
                            : () => controller.purchaseSubscription(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CustomColor.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: Dimensions.heightSize,
                        horizontal: Dimensions.widthSize * 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Dimensions.radius),
                      ),
                    ),
                    child:
                        controller.isLoading.value
                            ? SizedBox(
                              height: 20.h,
                              width: 20.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : Text(
                              'Subscribe Now',
                              style: CustomStyle.commonTextTitle.copyWith(
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),
                SizedBox(height: Dimensions.heightSize),
                // Restore Previous Purchase button removed as requested
              ],
            ),
          ),
        ],
      ),
    );
  }
}
