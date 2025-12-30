import 'package:get/get.dart';

class EditorController extends GetxController {
  final imagePath = RxnString();

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is String && arg.isNotEmpty) {
      imagePath.value = arg;
    }
  }
}
