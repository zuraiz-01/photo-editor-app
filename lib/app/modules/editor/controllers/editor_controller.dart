import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';

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

  Future<void> cropImage() async {
    final path = imagePath.value;
    if (path == null || path.isEmpty) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: path,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Crop', lockAspectRatio: false),
        IOSUiSettings(title: 'Crop'),
      ],
    );

    if (cropped == null) return;
    imagePath.value = cropped.path;
  }
}
