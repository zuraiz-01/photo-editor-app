import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';

import '../controllers/editor_controller.dart';

class _FilterThumb extends StatelessWidget {
  const _FilterThumb({
    required this.selected,
    required this.image,
    required this.onTap,
  });

  final bool selected;
  final Widget image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
                width: selected ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: image,
          ),
        ],
      ),
    );
  }
}

class EditorView extends GetView<EditorController> {
  const EditorView({super.key});

  static final GlobalKey _previewKey = GlobalKey();

  Future<void> _saveCurrentImage() async {
    try {
      final context = _previewKey.currentContext;
      if (context == null) {
        Get.snackbar('Save', 'Preview not ready');
        return;
      }
      final boundary = context.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        Get.snackbar('Save', 'Preview not ready');
        return;
      }

      final pixelRatio =
          ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        Get.snackbar('Save', 'Failed to export image');
        return;
      }
      await controller.saveToGallery(byteData.buffer.asUint8List());
    } catch (e) {
      Get.snackbar('Save failed', e.toString());
    }
  }

  void _openTextSheet(BuildContext context) {
    controller.beginTextEditing(id: controller.activeTextId.value);
    final textCtrl = TextEditingController(text: controller.draftText.value);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Obx(() {
              final fontSize = controller.draftFontSize.value;
              final color = controller.draftColor.value;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Text', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Enter text',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => controller.setDraftText(v),
                  ),
                  const SizedBox(height: 12),
                  Text('Size: ${fontSize.round()}'),
                  Slider(
                    value: fontSize.clamp(12.0, 72.0),
                    min: 12,
                    max: 72,
                    onChanged: controller.setDraftFontSize,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ColorDot(
                        color: Colors.white,
                        selected: color == Colors.white,
                        onTap: () => controller.setDraftColor(Colors.white),
                      ),
                      _ColorDot(
                        color: Colors.black,
                        selected: color == Colors.black,
                        onTap: () => controller.setDraftColor(Colors.black),
                      ),
                      _ColorDot(
                        color: Colors.red,
                        selected: color == Colors.red,
                        onTap: () => controller.setDraftColor(Colors.red),
                      ),
                      _ColorDot(
                        color: Colors.green,
                        selected: color == Colors.green,
                        onTap: () => controller.setDraftColor(Colors.green),
                      ),
                      _ColorDot(
                        color: Colors.blue,
                        selected: color == Colors.blue,
                        onTap: () => controller.setDraftColor(Colors.blue),
                      ),
                      _ColorDot(
                        color: Colors.yellow,
                        selected: color == Colors.yellow,
                        onTap: () => controller.setDraftColor(Colors.yellow),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            controller.setDraftText(textCtrl.text);
                            controller.commitDraftText();
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            controller.activeTextId.value == null
                                ? 'Add'
                                : 'Update',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: controller.activeTextId.value == null
                            ? null
                            : () {
                                controller.removeActiveText();
                                Navigator.of(context).pop();
                              },
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  void _openFiltersSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Obx(() {
              final intensity = controller.filterIntensity.value;
              final path = controller.imagePath.value;
              final selectedIndex = controller.selectedPresetIndex.value;

              final originalPreview = (path == null || path.isEmpty)
                  ? const SizedBox.shrink()
                  : Image.file(File(path), fit: BoxFit.cover);

              final matrix = controller.currentColorMatrix();
              final filteredPreview = (path == null || path.isEmpty)
                  ? const SizedBox.shrink()
                  : (matrix == null
                        ? originalPreview
                        : ColorFiltered(
                            colorFilter: ColorFilter.matrix(matrix),
                            child: originalPreview,
                          ));

              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Filters',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (path != null && path.isNotEmpty) ...[
                        Row(
                          children: [
                            Expanded(
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: originalPreview,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: filteredPreview,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 92,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: controller.presets.length,
                            itemBuilder: (context, index) {
                              final matrix = controller.matrixForPreset(
                                index,
                                1,
                              );
                              final thumb = matrix == null
                                  ? originalPreview
                                  : ColorFiltered(
                                      colorFilter: ColorFilter.matrix(matrix),
                                      child: originalPreview,
                                    );

                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _FilterThumb(
                                  selected: selectedIndex == index,
                                  image: thumb,
                                  onTap: () => controller.setPreset(index),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 16),
                      Text('Intensity: ${(intensity * 100).round()}%'),
                      Slider(
                        value: intensity,
                        min: 0,
                        max: 1,
                        onChanged: controller.setFilterIntensity,
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
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

          final matrix = controller.currentColorMatrix();
          final image = Image.file(File(path));
          final preview = matrix == null
              ? image
              : ColorFiltered(
                  colorFilter: ColorFilter.matrix(matrix),
                  child: image,
                );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return RepaintBoundary(
                  key: _previewKey,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          child: preview,
                        ),
                      ),
                      ...controller.texts.map((t) {
                        final left = t.dx * constraints.maxWidth;
                        final top = t.dy * constraints.maxHeight;
                        return Positioned(
                          left: left,
                          top: top,
                          child: GestureDetector(
                            onTap: () => controller.setActiveText(t.id),
                            onPanUpdate: (d) {
                              controller.moveTextByDelta(
                                id: t.id,
                                dx: d.delta.dx / constraints.maxWidth,
                                dy: d.delta.dy / constraints.maxHeight,
                              );
                            },
                            child: Obx(() {
                              final selected =
                                  controller.activeTextId.value == t.id;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: selected
                                      ? Border.all(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          width: 2,
                                        )
                                      : null,
                                  color: selected
                                      ? Theme.of(context).colorScheme.surface
                                            .withValues(alpha: 0.2)
                                      : Colors.transparent,
                                ),
                                child: Text(
                                  t.text,
                                  style: TextStyle(
                                    color: t.color,
                                    fontSize: t.fontSize,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
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
                icon: Icons.tune,
                label: 'Filter',
                onTap: () => _openFiltersSheet(context),
              ),
              _EditorOption(
                icon: Icons.text_fields,
                label: 'Text',
                onTap: () {
                  _openTextSheet(context);
                },
              ),
              _EditorOption(
                icon: Icons.save_alt,
                label: 'Save',
                onTap: _saveCurrentImage,
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

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}
