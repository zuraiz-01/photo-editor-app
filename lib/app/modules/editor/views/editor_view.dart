import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/editor_controller.dart';

class EditorView extends GetView<EditorController> {
  const EditorView({super.key});

  void _comingSoon(String title) {
    Get.snackbar(title, 'Coming soon');
  }

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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _EditorOption(
                icon: Icons.crop,
                label: 'Crop',
                onTap: controller.cropImage,
              ),
              _EditorOption(
                icon: Icons.rotate_right,
                label: 'Rotate',
                onTap: () => _comingSoon('Rotate'),
              ),
              _EditorOption(
                icon: Icons.tune,
                label: 'Filter',
                onTap: () => _comingSoon('Filter'),
              ),
              _EditorOption(
                icon: Icons.text_fields,
                label: 'Text',
                onTap: () => _comingSoon('Text'),
              ),
              _EditorOption(
                icon: Icons.save_alt,
                label: 'Save',
                onTap: () => _comingSoon('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorOption extends StatelessWidget {
  const _EditorOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
