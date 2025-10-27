import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/routes.dart';

List<String> yearList = ['Select Term', '2 Years', '3 Years', '5 Years'];
List<String> depositAmountList = ['Select Term', '\$ 50', '\$ 100', '\$ 200'];
List<String> frequencyList = [
  'Select Deposit Frequency ',
  'Weekly',
  'Monthly',
  'Yearly',
];

class SavingsController extends GetxController
    with GetSingleTickerProviderStateMixin {
  RxDouble animatedHeight = 130.0.obs;
  RxBool isChecked = false.obs;
  RxInt activeIndex = 0.obs;

  RxString termDropdownValue = yearList[0].obs;
  RxString depositFrequencyDropdownValue = frequencyList[0].obs;
  RxString depositAmountValue = depositAmountList[0].obs;
  final List<String> yearValueList = yearList;
  final List<String> depositFrequencyValueList = frequencyList;
  final List<String> depositAmountValueList = depositAmountList;

  final pinAddMoneyController = TextEditingController();
  final dropdownController = TextEditingController();
  final depositAmountController = TextEditingController();

  // overriding the dispose in getx controller
  @override
  void dispose() {
    pinAddMoneyController.dispose();
    dropdownController.dispose();
    depositAmountController.dispose();
    super.dispose();
  }

  void changeIndicator(int value) {
    activeIndex.value = value;
  }

  void changeAnimatedHeight(value) {
    animatedHeight.value = value;
  }

  void navigateToDashboardScreen() {
    Get.toNamed(Routes.navigationScreen);
  }

  void navigateToSchemeScreen() {
    Get.toNamed(Routes.schemeScreen);
  }

  void navigateToAddTermAndFrequencyScreen() {
    Get.toNamed(Routes.addTermAndFrequencyScreen);
  }

  void navigateToDepositAmountScreen() {
    Get.toNamed(Routes.depositAmountScreen);
  }

  void navigateToReviewSavingScreen() {
    Get.toNamed(Routes.reviewSavingScreen);
  }

  void navigateToConfirmSavingScreen() {
    Get.toNamed(Routes.confirmSavingScreen);
  }

  void navigateToDataSavingScreen() {
    Get.toNamed(Routes.dataSavingScreen);
  }

  void navigateToDataShowScreen() {
    Get.toNamed(Routes.dataShowScreen);
  }

  void navigateToHistorySavingScreen() {
    Get.toNamed(Routes.historySavingScreen);
  }
}
