import 'package:get/get.dart';

import '../routes/routes.dart';

class NavigationController extends GetxController {
  var currentIndex = 0.obs;
  List pages = [];

  void onTapChangeIndex(int index) {
    currentIndex.value = index;
    update();
  }

  void navigateToTransferMoneyScreen() {
    Get.toNamed(Routes.transferMoneyScreen);
  }
}
