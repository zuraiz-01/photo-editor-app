import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo Editor')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Select an image to start editing'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: controller.pickFromGallery,
              child: const Text('Pick from Gallery'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: controller.pickFromCamera,
              child: const Text('Capture from Camera'),
            ),
          ],
        ),
      ),
    );
  }
}
