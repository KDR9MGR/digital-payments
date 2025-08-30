import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xpay/utils/dimensions.dart';
import 'package:xpay/views/dashboard/dashboard_screen.dart';
import 'package:xpay/views/dashboard/inbox_screen.dart';

import '../controller/navigation_controller.dart';
import '../utils/custom_color.dart';
import '../utils/strings.dart';
import '../widgets/bottom_navbar_widget.dart';
import '../controller/subscription_controller.dart';
import '../screens/paywall_screen.dart';
import '../utils/app_logger.dart';
import '../widgets/subscription_guard.dart';

class NavigationScreen extends StatelessWidget {
  NavigationScreen({super.key});
  final _controller = Get.put(NavigationController());

  @override
  Widget build(BuildContext context) {
    return SubscriptionGuard(
      child: Scaffold(
        bottomNavigationBar: BottomNavBar(),
        body: Obx(
          () => IndexedStack(
            index: _controller.currentIndex.value,
            children: [DashboardScreen(), const IndexScreen()],
          ),
        ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            // backgroundColor:
            onPressed: () {
              _requireSubscriptionForTransfer();
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: CustomColor.primaryColor,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(15),
              side: const BorderSide(
                color: CustomColor.secondaryColor,
                width: 4,
              ),
            ),
            child: Image.asset(Strings.paperPlaneImagePath, scale: 1.2),
          ),
          SizedBox(height: Dimensions.heightSize),
          Text(
            Strings.transfer.tr,
            style: TextStyle(
              color: CustomColor.primaryColor,
              fontSize: Dimensions.smallestTextSize,
              fontWeight: FontWeight.w200,
            ),
          ),
          SizedBox(height: Dimensions.heightSize * 0.5),
        ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  /// Helper method to check subscription before transfer (optimized for instant response)
  void _requireSubscriptionForTransfer() async {
    final subscriptionController = Get.find<SubscriptionController>();

    try {
      // Check current status for instant response
      final hasActiveSubscription =
          subscriptionController.hasActiveSubscription;

      if (hasActiveSubscription) {
        _controller.navigateToTransferMoneyScreen();
      } else {
        // Show paywall immediately
        Get.to(
          () => const PaywallScreen(),
          fullscreenDialog: true,
          transition: Transition.cupertino,
        );
      }
    } catch (e) {
      AppLogger.log('Error checking subscription: $e');
      // Show paywall on error to be safe
      Get.to(
        () => const PaywallScreen(),
        fullscreenDialog: true,
        transition: Transition.cupertino,
      );
    }
  }
}
