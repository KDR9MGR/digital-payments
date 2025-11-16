import 'package:get/get.dart';

class InputImageController extends GetxController {
  RxBool isImagePathSet = false.obs;
RxString imagePath = ''.obs;

  void setImagePath(String path) {
    imagePath.value = path;
    isImagePathSet.value = true;
  }
}
