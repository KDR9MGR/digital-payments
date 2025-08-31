import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xpay/data/user_model.dart';
import 'package:xpay/views/auth/user_provider.dart';

import '../routes/routes.dart';

class SettingsController extends GetxController {
  File? userPhoto;
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final mobileController = TextEditingController();
  final addressController = TextEditingController();
  final stateController = TextEditingController();
  final cityController = TextEditingController();
  final zipController = TextEditingController();
  final countryController = TextEditingController();
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmController = TextEditingController();

  var selectedLanguage = ''.obs;

  void onChangeLanguage(var language) {
    selectedLanguage.value = language;
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    mobileController.dispose();
    addressController.dispose();
    stateController.dispose();
    cityController.dispose();
    zipController.dispose();
    countryController.dispose();
    countryController.dispose();
    oldPasswordController.dispose();
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  void navigateToDashboardScreen() {
    Get.toNamed(Routes.navigationScreen);
  }

  void navigateToUpdateProfileScreen() {
    Get.toNamed(Routes.updateProfileScreen);
  }

  void navigateToChangePasswordScreen() {
    Get.toNamed(Routes.changePasswordScreen);
  }

  void navigateToTwoFaSecurity() {
    Get.toNamed(Routes.twoFaSecurity);
  }

  void navigateToChangeLanguageScreen() {
    Get.toNamed(Routes.changeLanguageScreen);
  }

  void bindData(UserModel user) {
    firstNameController.text = user.firstName;
    lastNameController.text = user.lastName;
    emailController.text = user.emailAddress;
    mobileController.text = user.mobile;
    addressController.text = user.address ??= '';
    stateController.text = user.state ??= '';
    cityController.text = user.city ??= '';
    zipController.text = user.zipCode ??= '';
  }

  void showDeleteAccountConfirmation() {
    Get.dialog(
      AlertDialog(
        title: Text('Delete Account'),
        content: Text(
          'Are you sure you want to delete your account? This action cannot be undone and will permanently remove all your data.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              _deleteAccount();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() async {
    try {
      // Show loading dialog
      Get.dialog(
        AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Deleting account...'),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      // Clear local storage data
      await _clearLocalData();

      // Delete Firebase account and Firestore data using UserProvider
      final userProvider = Get.find<UserProvider>();
      await userProvider.deleteAccount();

      Get.back(); // Close loading dialog
      Get.snackbar(
        'Account Deleted',
        'Your account has been successfully deleted.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Navigate to login screen
      Get.offAllNamed(Routes.loginScreen);
    } catch (e) {
      Get.back(); // Close loading dialog
      Get.snackbar(
        'Error',
        'Failed to delete account: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _clearLocalData() async {
    try {
      // Clear all local storage data

      // Reset any app state
      selectedLanguage.value = '';

      // Clear all text controllers
      firstNameController.clear();
      lastNameController.clear();
      emailController.clear();
      mobileController.clear();
      addressController.clear();
      stateController.clear();
      cityController.clear();
      zipController.clear();
      countryController.clear();
      oldPasswordController.clear();
      newPasswordController.clear();
      confirmController.clear();
    } catch (e) {
      throw Exception('Failed to clear local data: ${e.toString()}');
    }
  }
}
