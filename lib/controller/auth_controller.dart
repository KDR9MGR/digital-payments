import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/routes.dart';

class AuthController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final firstNameAuthController = TextEditingController();
  final lastNameAuthController = TextEditingController();
  final emailAuthController = TextEditingController();
  final phoneNumberAuthController = TextEditingController();

  final pinLoginController = TextEditingController();

  final legalNameOfCompanyController = TextEditingController();
  final representativeFirstNameController = TextEditingController();
  final representativeLastNameController = TextEditingController();

  final companyPasswordController = TextEditingController();
  final companyConfirmPasswordController = TextEditingController();
  final companyEmailAuthController = TextEditingController();
  final companyUsernameController = TextEditingController();
  final companyPhoneNumberAuthController = TextEditingController();
  final countryController = TextEditingController();

  RxBool isChecked = false.obs;
  RxString countryCode = '+1'.obs;

  late TabController tabController;

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: 2, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    phoneNumberAuthController.dispose();
    firstNameAuthController.dispose();
    lastNameAuthController.dispose();
    emailAuthController.dispose();
    pinLoginController.dispose();
    companyPasswordController.dispose();
    companyConfirmPasswordController.dispose();
    companyEmailAuthController.dispose();
    companyUsernameController.dispose();
    companyPhoneNumberAuthController.dispose();
    countryController.dispose();
    super.dispose();
  }

  void navigateToRegisterScreen() {
    Get.toNamed(Routes.registerScreen);
  }

  void navigateToForgetPinScreen() {
    Get.toNamed(Routes.forgetPasswordScreen);
  }

  void navigateToOTPScreen() {
    Get.toNamed(Routes.otpScreen);
  }

  void navigateToResetPasswordScreen() {
    Get.toNamed(Routes.resetPasswordScreen);
  }

  void navigateToLoginScreen() {
    Get.toNamed(Routes.loginScreen);
  }

  void navigateToNidPassportScreen() {
    Get.toNamed(Routes.nidPassportScreen);
  }

  void navigateToCongratulationsScreen() {
    Get.toNamed(Routes.congratulationsScreen);
  }

  void navigateToDashboardScreen() {
    Get.toNamed(Routes.navigationScreen);
  }
}
