import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../controller/subscription_controller.dart';
import '../../config/stripe_config.dart';
import '../../utils/custom_color.dart';
import '../../utils/custom_style.dart';
import '../../utils/dimensions.dart';

class SubscriptionPlansScreen extends StatelessWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SubscriptionController>(
      builder: (controller) => Scaffold(
        backgroundColor: CustomColor.screenBGColor,
        appBar: AppBar(
          title: Text(
            'Go Premium',
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
        ),
        body: Obx(() => controller.isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _bodyWidget(context, controller)
        ),
      ),
    );
  }

  _bodyWidget(BuildContext context, SubscriptionController controller) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
      child: Column(
        children: [
          _headerWidget(),
          SizedBox(height: Dimensions.heightSize * 3),
          _premiumPlanWidget(controller),
          SizedBox(height: Dimensions.heightSize * 3),
          _subscribeButtonWidget(controller),
          SizedBox(height: Dimensions.heightSize * 2),
          _featuresListWidget(),
        ],
      ),
    );
  }

  _headerWidget() {
    return Container(
      padding: EdgeInsets.all(Dimensions.defaultPaddingSize * 1.2),
      decoration: BoxDecoration(
        gradient: CustomColor.primaryGradient,
        borderRadius: BorderRadius.circular(Dimensions.radius * 2),
        boxShadow: [
          BoxShadow(
            color: CustomColor.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.workspace_premium,
            size: 80.r,
            color: CustomColor.primaryTextColor,
          ),
          SizedBox(height: Dimensions.heightSize * 1.5),
          Text(
            'Unlock Premium Features',
            style: CustomStyle.commonLargeTextTitleWhite.copyWith(
              fontSize: Dimensions.extraLargeTextSize + 2,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Dimensions.heightSize),
          Text(
            'Get access to all premium features for just \$1.99/month',
            style: CustomStyle.commonSubTextTitle.copyWith(
              color: CustomColor.primaryTextColor.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  _premiumPlanWidget(SubscriptionController controller) {
    final planData = controller.singlePlan;
    if (planData == null) return const SizedBox();
    
    return Container(
      padding: EdgeInsets.all(Dimensions.defaultPaddingSize * 0.8),
      decoration: BoxDecoration(
        color: CustomColor.surfaceColor,
        borderRadius: BorderRadius.circular(Dimensions.radius * 2),
        border: Border.all(
          color: CustomColor.primaryColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: CustomColor.primaryColor.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Plan header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            planData['name'],
                            style: CustomStyle.commonTextTitle.copyWith(
                              fontSize: Dimensions.largeTextSize,
                              color: CustomColor.primaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        SizedBox(width: Dimensions.widthSize * 0.5),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Dimensions.defaultPaddingSize * 0.3,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: CustomColor.primaryColor,
                            borderRadius: BorderRadius.circular(Dimensions.radius),
                          ),
                          child: Text(
                            'POPULAR',
                            style: TextStyle(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.bold,
                              color: CustomColor.primaryTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Dimensions.heightSize * 0.5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            '\$${planData['price']}',
                            style: CustomStyle.commonLargeTextTitleWhite.copyWith(
                              fontSize: 28.sp,
                              color: CustomColor.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '/month',
                          style: CustomStyle.commonSubTextTitle.copyWith(
                            fontSize: Dimensions.mediumTextSize,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.verified,
                size: 32.r,
                color: CustomColor.primaryColor,
              ),
            ],
          ),
          
          SizedBox(height: Dimensions.heightSize * 1.5),
          
          // Value proposition
          Container(
            padding: EdgeInsets.all(Dimensions.defaultPaddingSize * 0.8),
            decoration: BoxDecoration(
              color: CustomColor.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Dimensions.radius),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.savings,
                  color: CustomColor.primaryColor,
                  size: 20.r,
                ),
                SizedBox(width: Dimensions.widthSize * 0.5),
                Expanded(
                  child: Text(
                    'Best value for premium features',
                    style: CustomStyle.commonTextTitle.copyWith(
                      color: CustomColor.primaryColor,
                      fontSize: Dimensions.smallTextSize,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _featuresListWidget() {
    final planData = StripeConfig.subscriptionPlans['premium_monthly'];
    if (planData == null) return const SizedBox();
    
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
            'What\'s Included:',
            style: CustomStyle.commonTextTitle.copyWith(
              fontSize: Dimensions.largeTextSize,
            ),
          ),
          SizedBox(height: Dimensions.heightSize * 1.5),
          ...List.generate(
            planData['features'].length,
            (index) => Container(
              margin: EdgeInsets.only(bottom: Dimensions.heightSize),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(4.r),
                    decoration: BoxDecoration(
                      color: CustomColor.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 16.r,
                      color: CustomColor.primaryTextColor,
                    ),
                  ),
                  SizedBox(width: Dimensions.widthSize),
                  Expanded(
                    child: Text(
                      planData['features'][index],
                      style: CustomStyle.commonSubTextTitle.copyWith(
                        fontSize: Dimensions.defaultTextSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _subscribeButtonWidget(SubscriptionController controller) {
    return Column(
      children: [
        // Google Pay button (Android)
        if (controller.googlePayAvailable) ...[
          SizedBox(
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
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.payment,
                      color: Colors.white,
                      size: 24.r,
                    ),
                  ),
                  SizedBox(width: Dimensions.widthSize),
                  Text(
                    'Pay with Google Pay',
                    style: CustomStyle.commonTextTitle.copyWith(
                      color: Colors.white,
                      fontSize: Dimensions.mediumTextSize,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: Dimensions.heightSize),
        ],
        
        // Apple Pay button (iOS)
        if (controller.applePayAvailable) ...[
          SizedBox(
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
                  Icon(
                    Icons.apple,
                    color: Colors.white,
                    size: 24.r,
                  ),
                  SizedBox(width: Dimensions.widthSize),
                  Text(
                    'Pay with Apple Pay',
                    style: CustomStyle.commonTextTitle.copyWith(
                      color: Colors.white,
                      fontSize: Dimensions.mediumTextSize,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: Dimensions.heightSize),
        ],
        
        // No payment method available message
        if (!controller.googlePayAvailable && !controller.applePayAvailable) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
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
    );
  }
} 