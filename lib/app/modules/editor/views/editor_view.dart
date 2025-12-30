import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/editor_controller.dart';

class EditorView extends GetView<EditorController> {
  const EditorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editor')),
      body: Center(
        child: Obx(() {
          final path = controller.imagePath.value;
          if (path == null || path.isEmpty) {
            return const Text('No image selected');
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Image.file(File(path)),
          );
        }),
      ),
    );
  }
}
