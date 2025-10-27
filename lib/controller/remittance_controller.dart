import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/routes.dart';

class RemittanceController extends GetxController {
  RxDouble animatedHeight = 130.0.obs;

  final phoneNumberRemittanceController = TextEditingController();
  final amountRemittanceController = TextEditingController();
  final pinRemittanceController = TextEditingController();
  final referenceRemittanceController = TextEditingController();

  @override
  void dispose() {
    phoneNumberRemittanceController.dispose();
    pinRemittanceController.dispose();
    referenceRemittanceController.dispose();
    amountRemittanceController.dispose();
    super.dispose();
  }

  void changeAnimatedHeight(value) {
    animatedHeight.value = value;
  }

  void navigateToAddAmountRemittanceMoneyScreen() {
    Get.toNamed(Routes.addAmountRemittanceMoneyScreen);
  }

  void navigateToPinRemittanceScreen() {
    Get.toNamed(Routes.pinRemittanceScreen);
  }

  void navigateToReviewRemittanceScreen() {
    Get.toNamed(Routes.reviewRemittanceScreen);
  }

  void navigateToDashboardScreen() {
    Get.toNamed(Routes.navigationScreen);
  }
}
