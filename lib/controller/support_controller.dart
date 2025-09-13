import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/routes.dart';

class SupportController extends GetxController {
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final subjectController = TextEditingController();
  final messageController = TextEditingController();

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    subjectController.dispose();
    messageController.dispose();
    super.dispose();
  }

  void navigateToDashboardScreen() {
    Get.toNamed(Routes.navigationScreen);
  }

  void navigateToCreateSupportTicketScreen() {
    Get.toNamed(Routes.createSupportTicketScreen);
  }

  void navigateToMySupportTickets() {
    Get.toNamed(Routes.mySupportTickets);
  }
}
