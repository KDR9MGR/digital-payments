import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/routes.dart';

class InvoiceController extends GetxController {
  final dropdownWalletController = TextEditingController();
  final invoiceToController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  final amountController = TextEditingController();
  final itemNameController = TextEditingController();

  List<String> walletList = ['USD', 'GBP', 'BDT'];
  RxString walletName = ''.obs;
  RxDouble charge = 0.00.obs;
  RxDouble chargeCalculated = 0.00.obs;
  RxDouble fixedCharge = 0.00.obs;

  double calculateCharge(double value) {
    fixedCharge.value = 1.00;
    charge.value = 0.00;
    chargeCalculated.value = 0.00;
    // double extraCharge = value * .01;
    // chargeCalculated.value = extraCharge;
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
    walletName.value = walletList[0];
    amountController.text = '0';
    super.onInit();
  }

  @override
  void dispose() {
    dropdownWalletController.dispose();
    invoiceToController.dispose();
    amountController.dispose();
    emailController.dispose();
    addressController.dispose();
    itemNameController.dispose();

    super.dispose();
  }

  void navigateToDashboardScreen() {
    Get.toNamed(Routes.navigationScreen);
  }

  void navigateToTransferMoneyScanQrCodeScreen() {
    Get.toNamed(Routes.transferMoneyScanQrCodeScreen);
  }

  void navigateToInvoiceUpdateScreen() {
    Get.toNamed(Routes.invoiceUpdateScreen);
  }

  void navigateToInvoicePreviewScreen() {
    Get.toNamed(Routes.invoicePreviewScreen);
  }

  void navigateToConfirmInvoiceScreen() {
    Get.toNamed(Routes.confirmInvoiceScreen);
  }

  void navigateToCreateInvoiceScreen() {
    Get.toNamed(Routes.createInvoiceScreen);
  }
}
