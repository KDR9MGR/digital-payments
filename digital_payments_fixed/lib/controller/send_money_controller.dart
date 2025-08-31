import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/routes.dart';

class SendMoneyController extends GetxController {
  RxDouble animatedHeight = 130.0.obs;

  final phoneNumberSendMoneyController = TextEditingController();
  final amountSendMoneyController = TextEditingController();
  final pinSendMoneyController = TextEditingController();
  final referenceSendMoneyController = TextEditingController();

  @override
  void dispose() {
    phoneNumberSendMoneyController.dispose();
    pinSendMoneyController.dispose();
    referenceSendMoneyController.dispose();
    amountSendMoneyController.dispose();
    super.dispose();
  }

  void changeAnimatedHeight(value) {
    animatedHeight.value = value;
  }

  void navigateToAddAmountScreen() {
    Get.toNamed(Routes.addAmountSendMoneyScreen);
  }

  void navigateToPinScreen() {
    Get.toNamed(Routes.pinScreen);
  }

  void navigateToReviewScreen() {
    Get.toNamed(Routes.reviewSendMoneyScreen);
  }

  void navigateToDashboardScreen() {
    Get.toNamed(Routes.navigationScreen);
  }
}
