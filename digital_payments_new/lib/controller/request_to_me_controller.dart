import 'package:get/get.dart';

import '../routes/routes.dart';

class RequestToMeController extends GetxController {
  RxString methodName = ''.obs;
  RxString walletName = ''.obs;
  RxString currencyName = ''.obs;

  void navigateToDashboardScreen() {
    Get.toNamed(Routes.navigationScreen);
  }

  void navigateToRequestToMeWalletInfoScreen() {
    Get.toNamed(Routes.requestToMeWalletInfoScreen);
  }

  void navigateToConfirmRequestToMeScreen() {
    Get.toNamed(Routes.confirmRequestToMeScreen);
  }
}
