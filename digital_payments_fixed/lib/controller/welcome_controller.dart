import 'package:get/get.dart';

import '../routes/routes.dart';

class WelcomeController extends GetxController {
  // all navigation from welcome screen
  void navigateToLogin() {
    Get.toNamed(Routes.loginScreen);
  }

  void navigateToRegisterScreen() {
    Get.toNamed(Routes.registerScreen);
  }
}
