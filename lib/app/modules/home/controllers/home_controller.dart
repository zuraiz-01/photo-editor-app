import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../routes/app_routes.dart';

class HomeController extends GetxController {
  final _picker = ImagePicker();
  final isPicking = false.obs;

  Future<void> pickFromGallery() async {
    if (isPicking.value) return;
    isPicking.value = true;
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      Get.toNamed(Routes.editor, arguments: file.path);
    } on PlatformException catch (e) {
      if (e.code == 'already_active') return;
      rethrow;
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> pickFromCamera() async {
    if (isPicking.value) return;
    isPicking.value = true;
    try {
      final file = await _picker.pickImage(source: ImageSource.camera);
      if (file == null) return;
      Get.toNamed(Routes.editor, arguments: file.path);
    } on PlatformException catch (e) {
      if (e.code == 'already_active') return;
      rethrow;
    } finally {
      isPicking.value = false;
    }
  }
}
