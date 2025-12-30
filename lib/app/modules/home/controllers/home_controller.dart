import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../routes/app_routes.dart';

class HomeController extends GetxController {
  final _picker = ImagePicker();

  Future<void> pickFromGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    Get.toNamed(Routes.editor, arguments: file.path);
  }

  Future<void> pickFromCamera() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file == null) return;
    Get.toNamed(Routes.editor, arguments: file.path);
  }
}
