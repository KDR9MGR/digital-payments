import 'package:firebase_auth/firebase_auth.dart';
import '/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../routes/routes.dart';
import '../controller/subscription_controller.dart';
import '../screens/paywall_screen.dart';

List<String> languageList = ['English ', 'Spanish', 'Chinese', 'Hindi'];

class DashboardController extends GetxController {
  RxBool showBalance = true.obs;
  RxInt activeIndex = 0.obs;
  RxBool isPending = false.obs;
  RxString termDropdownValue = languageList[0].obs;

  final List<String> languageValueList = languageList;

  final changeNameController = TextEditingController();
  final chatController = TextEditingController();
  final dropdownController = TextEditingController();
  final nidNameController = TextEditingController();
  final nidNumberController = TextEditingController();

  @override
  void dispose() {
    changeNameController.dispose();
    chatController.dispose();
    dropdownController.dispose();
    super.dispose();
  }

  void navigateToDashboardScreen() {
    Get.toNamed(Routes.navigationScreen);
  }

  Future<void> changeBalanceStatus() async {
    showBalance.value = !showBalance.value;
    await Future.delayed(const Duration(seconds: 5));
    showBalance.value = !showBalance.value;
  }

  void changeIndicator(int value) {
    activeIndex.value = value;
  }

  void navigateToInvoiceScreen() {
    Get.toNamed(Routes.invoiceScreen);
  }

  void navigateToVoucherScreen() {
    Get.toNamed(Routes.voucherScreen);
  }

  void navigateToSendMoney() {
    Get.toNamed(Routes.addNumberSendMoneyScreen);
  }

  void navigateToMakePaymentScreen() {
    _requireSubscriptionForNavigation(
      () => Get.toNamed(Routes.makePaymentScreen),
    );
  }

  void navigateToMoneyOutScreen() {
    _requireSubscriptionForNavigation(() => Get.toNamed(Routes.moneyOutScreen));
  }

  void navigateToAddNumberPaymentScreen() {
    _requireSubscriptionForNavigation(
      () => Get.toNamed(Routes.addNumberPaymentScreen),
    );
  }

  void navigateToAddMoneyScreen() {
    _requireSubscriptionForNavigation(
      () => Get.toNamed(Routes.addMoneyMoneyScreen),
    );
  }

  void navigateToRequestScreen() {
    _requireSubscriptionForNavigation(() => Get.toNamed(Routes.requestScreen));
  }

  void navigateToTransferMoneyScreen() {
    _requireSubscriptionForNavigation(
      () => Get.toNamed(Routes.transferMoneyScreen),
    );
  }

  void navigateToInternalTransferScreen() {
    _requireSubscriptionForNavigation(
      () => Get.toNamed(Routes.internalTransferScreen),
    );
  }

  void navigateToCurrencyExchangeScreen() {
    _requireSubscriptionForNavigation(
      () => Get.toNamed(Routes.currencyExchangeScreen),
    );
  }

  void navigateToSavingRulesScreen() {
    _requireSubscriptionForNavigation(
      () => Get.toNamed(Routes.savingRulesScreen),
    );
  }

  void navigateToRemittanceSourceScreen() {
    _requireSubscriptionForNavigation(
      () => Get.toNamed(Routes.remittanceSourceScreen),
    );
  }

  void navigateToWithdrawScreen() {
    _requireSubscriptionForNavigation(() => Get.toNamed(Routes.withdrawScreen));
  }

  void navigateToRequestToMeScreen() {
    _requireSubscriptionForNavigation(
      () => Get.toNamed(Routes.requestToMeScreen),
    );
  }

  void navigateToAddMoneyHistoryScreen() {
    _requireSubscriptionForNavigation(
      () => Get.toNamed(Routes.addMoneyHistoryScreen),
    );
  }

  void navigateToTransactionHistoryScreen() {
    _requireSubscriptionForNavigation(
      () => Get.toNamed(Routes.transactionsHistoryScreen),
    );
  }

  void navigateToWithdrawHistoryScreen() {
    _requireSubscriptionForNavigation(
      () => Get.toNamed(Routes.withdrawHistoryScreen),
    );
  }

  void navigateToMyQrCodeScreen() {
    _requireSubscriptionForNavigation(() => Get.toNamed(Routes.myQrCodeScreen));
  }

  void navigateToXPayMapScreen() {
    _requireSubscriptionForNavigation(() => Get.toNamed(Routes.xPayMapScreen));
  }

  void navigateToSettingScreen() {
    Get.toNamed(Routes.settingsScreen);
  }

  void navigateToChangeNameScreen() {
    Get.toNamed(Routes.changeNameScreen);
  }

  void navigateToChangePictureScreen() {
    Get.toNamed(Routes.changePictureScreen);
  }

  void navigateToSupportScreen() {
    Get.toNamed(Routes.supportScreen);
  }

  void navigateToLiveChatScreen() {
    Get.toNamed(Routes.liveChatScreen);
  }

  void navigateToVerifyAccountScreen() {
    Get.toNamed(Routes.verifyAccountScreen);
  }

  /// Helper method to check subscription before navigation (optimized for instant response)
  void _requireSubscriptionForNavigation(VoidCallback navigation) async {
    final subscriptionController = Get.find<SubscriptionController>();

    try {
      // Check current status for instant response
      final hasActiveSubscription =
          subscriptionController.hasActiveSubscription;

      if (hasActiveSubscription) {
        navigation();
      } else {
        // Show paywall but allow going back
        Get.to(
          () => const PaywallScreen(),
          fullscreenDialog: true,
          transition: Transition.cupertino,
        );
      }
    } catch (e) {
      AppLogger.log('Error checking subscription: $e');
      // On error, allow user to continue - don't force paywall
      navigation();
    }
  }

  Future<void> signOut() async {
    try {
      await GetStorage().erase();

      await FirebaseAuth.instance.signOut();
      Get.offAllNamed(Routes.onBoardScreen);
    } catch (e) {
      AppLogger.log('Error signing out: $e');
    }
  }
}
