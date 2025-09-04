import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/routes.dart';
import '../utils/app_logger.dart';

class PaymentController extends GetxController {
  final dropdownWalletController = TextEditingController();
  final merchantUsernameOrEmailController = TextEditingController();
  final amountController = TextEditingController();

  List<String> walletList = ['USD', 'GBP', 'BDT'];
  RxString walletName = ''.obs;
  RxDouble charge = 0.00.obs;
  RxDouble chargeCalculated = 0.00.obs;
  RxDouble fixedCharge = 0.00.obs;
  
  // Payment method properties
  List<String> paymentMethods = ['Bank Account', 'Debit Card', 'Credit Card', 'Wallet Balance'];
  RxString selectedPaymentMethod = ''.obs;

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
    walletName.value = walletList[0];
    amountController.text = '0';
    _initializePaymentMethod();
    super.onInit();
  }

  // Initialize payment method with proper error handling
  void _initializePaymentMethod() {
    if (paymentMethods.isNotEmpty) {
      selectedPaymentMethod.value = paymentMethods[0];
    } else {
      // Fallback payment methods if list is empty
      paymentMethods = ['Bank Account', 'Debit Card', 'Credit Card', 'Wallet Balance'];
      selectedPaymentMethod.value = paymentMethods[0];
      AppLogger.log('Payment methods list was empty, initialized with default methods');
    }
  }

  // Validate payment method selection
  bool validatePaymentMethod() {
    if (selectedPaymentMethod.value.isEmpty) {
      _initializePaymentMethod();
      return false;
    }
    
    if (!paymentMethods.contains(selectedPaymentMethod.value)) {
      AppLogger.log('Selected payment method not in available methods, resetting to first available');
      selectedPaymentMethod.value = paymentMethods.isNotEmpty ? paymentMethods[0] : '';
      return false;
    }
    
    return true;
  }

  // Refresh payment methods if needed
  void refreshPaymentMethods() {
    if (paymentMethods.isEmpty) {
      _initializePaymentMethod();
      AppLogger.log('Payment methods refreshed due to empty list');
    }
  }

  // Get current payment method with fallback
  String getCurrentPaymentMethod() {
    if (selectedPaymentMethod.value.isEmpty || !paymentMethods.contains(selectedPaymentMethod.value)) {
      validatePaymentMethod();
    }
    return selectedPaymentMethod.value;
  }

  @override
  void dispose() {
    dropdownWalletController.dispose();
    merchantUsernameOrEmailController.dispose();
    amountController.dispose();

    super.dispose();
  }

  void navigateToDashboardScreen() {
    Get.toNamed(Routes.navigationScreen);
  }

  void navigateToMakePaymentScanQrCodeScreen() {
    Get.toNamed(Routes.makePaymentScanQrCodeScreen);
  }

  void navigateToConfirmMakePaymentOutScreen() {
    Get.toNamed(Routes.confirmMakePaymentOutScreen);
  }
}
