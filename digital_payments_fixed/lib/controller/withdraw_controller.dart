import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/routes.dart';

class WithdrawController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final dropdownMethodController = TextEditingController();
  final dropdownCurrencyController = TextEditingController();
  final dropdownWalletController = TextEditingController();
  final gatewayNameController = TextEditingController();
  final amountController = TextEditingController();
  final provideANickNameHint = TextEditingController();

  List<String> walletList = ['USD', 'GBP', 'BDT'];
  List<String> methodList = ['Paypal', 'Rasor Pay'];
  List<String> currencyList = ['USD', 'GBP', 'BDT'];
  RxString methodName = ''.obs;
  RxString walletName = ''.obs;
  RxString currencyName = ''.obs;
  RxDouble charge = 0.00.obs;
  RxDouble chargeCalculated = 0.00.obs;
  RxDouble fixedCharge = 0.00.obs;

  double calculateCharge(double value) {
    fixedCharge.value = 2.00;
    charge.value = 0.00;
    chargeCalculated.value = 0.00;
    double extraCharge = value * .01;
    chargeCalculated.value = extraCharge;
    charge.value = chargeCalculated.value + fixedCharge.value;
    if (value == 0) {
      chargeCalculated.value = 0.00;
      charge.value = 0.00;
      return 0.00;
    }
    return chargeCalculated.value + fixedCharge.value;
  }

  @override
  void onInit() {
    methodName.value = methodList[0];
    currencyName.value = currencyList[0];
    walletName.value = walletList[0];
    amountController.text = '0';
    super.onInit();
  }

  @override
  void dispose() {
    dropdownMethodController.dispose();
    dropdownCurrencyController.dispose();
    dropdownWalletController.dispose();
    gatewayNameController.dispose();
    amountController.dispose();
    provideANickNameHint.dispose();

    super.dispose();
  }

  void navigateToDashboardScreen() {
    Get.toNamed(Routes.navigationScreen);
  }

  void navigateAddWithdrawMethodScreen() {
    Get.toNamed(Routes.addWithdrawMethodScreen);
  }

  void navigateWithdrawMoneyScreen() {
    Get.toNamed(Routes.withdrawMoneyScreen);
  }

  void navigateConfirmWithdrawMoneyScreen() {
    Get.toNamed(Routes.confirmWithdrawMoneyScreen);
  }
}
