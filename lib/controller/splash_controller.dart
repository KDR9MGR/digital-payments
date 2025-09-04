import 'dart:ui';

import 'package:get/get.dart';

import '../utils/local_storage.dart';

class SplashController extends GetxController {
  @override
  void onReady() {
    super.onReady();
    List<String> languageList = LocalStorage.getLanguage().cast<String>();
Locale locale = Locale(languageList[0], languageList[1]);
    Get.updateLocale(locale);
  }
}
