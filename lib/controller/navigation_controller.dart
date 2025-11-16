import 'package:get/get.dart';

import '../routes/routes.dart';

class NavigationController extends GetxController {
  RxInt currentIndex = 0.obs;

  void onTapChangeIndex(int index) {
    currentIndex.value = index;
    update();
  }

  void navigateToTransferMoneyScreen() {
    Get.toNamed(Routes.transferMoneyScreen);
  }

  void navigateToStripeOnboardingScreen() {
    Get.toNamed(Routes.stripeOnboardingScreen);
  }

  void navigateToSendMoneySimpleScreen() {
    Get.toNamed(Routes.sendMoneySimpleScreen);
  }
}
