import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../controllers/editor_controller.dart';
import '../../../theme/theme_controller.dart';

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

  Future<Uint8List?> _captureCurrentImageBytes() async {
    try {
      final context = _previewKey.currentContext;
      if (context == null) {
        Get.snackbar('Save', 'Preview not ready');
        return null;
      }
      final boundary = context.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        Get.snackbar('Save', 'Preview not ready');
        return null;
      }
      controller.isCapturing.value = true;
      await Future<void>.delayed(const Duration(milliseconds: 16));
      final pixelRatio =
          ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      controller.isCapturing.value = false;
      if (byteData == null) {
        Get.snackbar('Save', 'Failed to export image');
        return null;
      }
      return byteData.buffer.asUint8List();
    } catch (e) {
      controller.isCapturing.value = false;
      Get.snackbar('Save failed', e.toString());
      return null;
    }
  }

  Future<void> _openExportSheet(BuildContext context) async {
    ExportFormat format = ExportFormat.png;
    double quality = 0.9;
    String sizePreset = 'Original';
    double maxWidth = 2048;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Export', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    SegmentedButton<ExportFormat>(
                      segments: const [
                        ButtonSegment(
                          value: ExportFormat.png,
                          label: Text('PNG'),
                        ),
                        ButtonSegment(
                          value: ExportFormat.jpeg,
                          label: Text('JPEG'),
                        ),
                      ],
                      selected: {format},
                      onSelectionChanged: (v) =>
                          setState(() => format = v.first),
                    ),
                    const SizedBox(height: 12),
                    if (format == ExportFormat.jpeg) ...[
                      Text('Quality: ${(quality * 100).round()}%'),
                      Slider(
                        value: quality,
                        min: 0.5,
                        max: 1.0,
                        onChanged: (v) => setState(() => quality = v),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const SizedBox(height: 8),
                    Text('Resolution'),
                    const SizedBox(height: 4),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: sizePreset,
                      items: const [
                        DropdownMenuItem(value: 'Original', child: Text('Original size')),
                        DropdownMenuItem(value: '4096', child: Text('4096 px width')),
                        DropdownMenuItem(value: '2048', child: Text('2048 px width')),
                        DropdownMenuItem(value: '1080', child: Text('1080 px width')),
                        DropdownMenuItem(value: '720', child: Text('720 px width')),
                        DropdownMenuItem(value: 'Custom', child: Text('Custom width')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          sizePreset = v;
                          if (v != 'Custom' && v != 'Original') {
                            maxWidth = double.parse(v);
                          }
                        });
                      },
                    ),
                    if (sizePreset == 'Custom') ...[
                      Text('Max width: ${maxWidth.round()} px'),
                      Slider(
                        value: maxWidth,
                        min: 720,
                        max: 4096,
                        onChanged: (v) => setState(() => maxWidth = v),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () async {
                        final bytes = await _captureCurrentImageBytes();
                        if (bytes == null) return;
                        final converted = await controller.convertBytes(
                          bytes,
                          format: format,
                          quality: (quality * 100).round(),
                        );
                        final resized = await controller.resizeBytes(
                          converted,
                          maxWidth: sizePreset == 'Original'
                              ? null
                              : maxWidth.round(),
                        );
                        await controller.saveToGallery(
                          resized,
                          format: format,
                          quality: (quality * 100).round(),
                        );
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Save to Gallery'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final bytes = await _captureCurrentImageBytes();
                        if (bytes == null) return;
                        final converted = await controller.convertBytes(
                          bytes,
                          format: format,
                          quality: (quality * 100).round(),
                        );
                        final resized = await controller.resizeBytes(
                          converted,
                          maxWidth: sizePreset == 'Original'
                              ? null
                              : maxWidth.round(),
                        );
                        await controller.shareBytes(
                          resized,
                          format: format,
                        );
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Share'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
                  DropdownButton<String>(
                    value: controller.selectedFont.value,
                    isExpanded: true,
                    items: controller.fonts
                        .map((f) => DropdownMenuItem(
                              value: f,
                              child: Text(f),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) controller.selectedFont.value = v;
                    },
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
                  Wrap(
                    spacing: 12,
                    children: [
                      FilterChip(
                        label: const Text('Shadow'),
                        selected: controller.enableShadow.value,
                        onSelected: (v) => controller.enableShadow.value = v,
                      ),
                      FilterChip(
                        label: const Text('Glow'),
                        selected: controller.enableGlow.value,
                        onSelected: (v) => controller.enableGlow.value = v,
                      ),
                      FilterChip(
                        label: const Text('Curved'),
                        selected: controller.enableCurved.value,
                        onSelected: (v) => controller.enableCurved.value = v,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Outline: ${controller.outlineSize.value.toStringAsFixed(1)}'),
                  Slider(
                    value: controller.outlineSize.value,
                    min: 0,
                    max: 6,
                    onChanged: (v) => controller.outlineSize.value = v,
                  ),
                  const SizedBox(height: 8),
                  Text('Curve radius: ${controller.curveRadius.value.round()}'),
                  Slider(
                    value:
                        (controller.curveRadius.value.clamp(60, 260)).toDouble(),
                    min: 60,
                    max: 260,
                    onChanged: (v) => controller.curveRadius.value = v,
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
                  Text('Quick templates', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ('New drop just landed ✨', 'Insta caption'),
                      ('Stay humble. Hustle hard.', 'Quote'),
                      ('Flash Sale 50% OFF!', 'Sale banner'),
                      ('Limited stock. Grab now!', 'CTA'),
                    ].map((tpl) {
                      return OutlinedButton(
                        onPressed: () {
                          textCtrl.text = tpl.$1;
                          controller.setDraftText(tpl.$1);
                        },
                        child: Text(tpl.$2),
                      );
                    }).toList(),
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

  void _openAdjustmentsSheet(BuildContext context) {
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
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Adjustments',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _AdjustmentSlider(
                    label: 'Brightness',
                    value: controller.brightness.value,
                    min: -1,
                    max: 1,
                    onChanged: controller.setBrightness,
                  ),
                  _AdjustmentSlider(
                    label: 'Contrast',
                    value: controller.contrast.value,
                    min: -0.5,
                    max: 0.5,
                    onChanged: controller.setContrast,
                  ),
                  _AdjustmentSlider(
                    label: 'Exposure',
                    value: controller.exposure.value,
                    min: -1,
                    max: 1,
                    onChanged: controller.setExposure,
                  ),
                  _AdjustmentSlider(
                    label: 'Vibrance',
                    value: controller.vibrance.value,
                    min: -1,
                    max: 1,
                    onChanged: controller.setVibrance,
                  ),
                  _AdjustmentSlider(
                    label: 'Temperature',
                    value: controller.temperature.value,
                    min: -1,
                    max: 1,
                    onChanged: controller.setTemperature,
                  ),
                  _AdjustmentSlider(
                    label: 'Tilt X',
                    value: controller.skewX.value,
                    min: -0.5,
                    max: 0.5,
                    onChanged: controller.setSkewX,
                  ),
                  _AdjustmentSlider(
                    label: 'Tilt Y',
                    value: controller.skewY.value,
                    min: -0.5,
                    max: 0.5,
                    onChanged: controller.setSkewY,
                  ),
                  _AdjustmentSlider(
                    label: 'Blur',
                    value: controller.blur.value,
                    min: 0,
                    max: 1,
                    onChanged: controller.setBlur,
                  ),
                  _AdjustmentSlider(
                    label: 'Vignette',
                    value: controller.vignette.value,
                    min: 0,
                    max: 1,
                    onChanged: controller.setVignette,
                  ),
                  const Divider(),
                  Text('Frame', style: Theme.of(context).textTheme.titleSmall),
                  DropdownButton<int>(
                    value: controller.framePresetIndex.value,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('None')),
                      DropdownMenuItem(value: 1, child: Text('Clean White')),
                      DropdownMenuItem(value: 2, child: Text('Minimal Black')),
                      DropdownMenuItem(value: 3, child: Text('Gold Rounded')),
                      DropdownMenuItem(value: 4, child: Text('Neon Thin')),
                    ],
                    onChanged: (i) {
                      if (i != null) controller.applyFramePreset(i);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Show frame'),
                    value: controller.frameEnabled.value,
                    onChanged: controller.setFrameEnabled,
                  ),
                  if (controller.frameEnabled.value) ...[
                    _ColorPickerRow(
                      selected: controller.frameColor.value,
                      onSelect: controller.setFrameColor,
                    ),
                    Text('Frame width: ${controller.frameWidth.value.round()}'),
                    Slider(
                      value: controller.frameWidth.value,
                      min: 2,
                      max: 40,
                      onChanged: controller.setFrameWidth,
                    ),
                    Text('Corner radius: ${controller.frameRadius.value.round()}'),
                    Slider(
                      value: controller.frameRadius.value,
                      min: 0,
                      max: 60,
                      onChanged: controller.setFrameRadius,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text('Presets', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          final name = await _promptForText(context, 'Preset name');
                          if (name == null || name.trim().isEmpty) return;
                          controller.saveUserPreset(name.trim());
                        },
                        child: const Text('Save current'),
                      ),
                      if (controller.userPresets.isNotEmpty)
                        ...List.generate(controller.userPresets.length, (i) {
                          final preset = controller.userPresets[i];
                          return Chip(
                            label: Text(preset.name),
                            deleteIcon: const Icon(Icons.delete, size: 16),
                            onDeleted: () => controller.deletePreset(i),
                            avatar: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.play_arrow, size: 18),
                              onPressed: () => controller.applyUserPreset(i),
                              tooltip: 'Apply',
                            ),
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                            ),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            labelPadding: const EdgeInsets.only(right: 4),
                          );
                        }),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: controller.removeBgBusy.value
                        ? null
                        : () => _openRemoveBgSheet(context),
                    icon: const Icon(Icons.image_not_supported_outlined),
                    label: Obx(() => Text(
                        controller.removeBgBusy.value ? 'Removing...' : 'Remove Background')),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          controller.resetAdjustments();
                          controller.resetPerspective();
                        },
                        child: const Text('Reset'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
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

  void _openStickersSheet(BuildContext context) {
    final defaults = <String>[
      '😎',
      '🔥',
      '❤️',
      '😂',
      '✨',
      '👍',
      '😍',
      '🎉',
      '🥳',
      '😺',
      '🌈',
      '💯',
    ];

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
              final hasActive = controller.activeStickerId.value != null;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Stickers',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: GridView.builder(
                      scrollDirection: Axis.horizontal,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                          ),
                      itemCount: defaults.length,
                      itemBuilder: (context, index) {
                        final emoji = defaults[index];
                        return FilledButton.tonal(
                          onPressed: () =>
                              controller.addEmojiSticker(emoji: emoji),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final emoji = await _askForEmoji(context);
                      if (emoji == null) return;
                      controller.addEmojiSticker(emoji: emoji);
                    },
                    child: const Text('Add from Keyboard (Emoji)'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: hasActive
                              ? () {
                                  controller.removeActiveSticker();
                                }
                              : null,
                          child: const Text('Delete Selected'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: hasActive
                              ? () {
                                  controller.bringActiveStickerToFront();
                                }
                              : null,
                          child: const Text('Bring to Front'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  void _openTemplateSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Obx(() {
              final selected = controller.selectedTemplateIndex.value;
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Templates',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(controller.templates.length, (index) {
                        final template = controller.templates[index];
                        // ignore: deprecated_member_use
                        return RadioListTile<int>(
                          value: index,
                          // ignore: deprecated_member_use
                          groupValue: selected,
                          // ignore: deprecated_member_use
                          onChanged: (v) => controller.setTemplate(v ?? 0),
                          title: Text(template.name),
                          dense: true,
                        );
                      }),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('Safe area guide'),
                        value: controller.safeAreaEnabled.value,
                        onChanged: controller.setSafeAreaEnabled,
                      ),
                      DropdownButton<int>(
                        value: controller.safeAreaPresetIndex.value,
                        isExpanded: true,
                        items: List.generate(
                          controller.safeAreas.length,
                          (i) => DropdownMenuItem(
                            value: i,
                            child: Text(controller.safeAreas[i].name),
                          ),
                        ),
                        onChanged: (i) {
                          if (i != null) controller.setSafeAreaPreset(i);
                        },
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

  void _openBrushSheet(BuildContext context) {
    final colors = <Color>[
      Colors.white,
      Colors.black,
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.amber,
      Colors.purple,
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Obx(() {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('Brush', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                  Switch(
                    value: controller.isDrawing,
                    onChanged: (v) => controller.isDrawing = v,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Eraser mode'),
                value: controller.eraserMode,
                onChanged: (v) => controller.setEraserMode(v),
              ),
              const SizedBox(height: 4),
              Text('Size: ${controller.strokeWidth.value.round()}'),
              Slider(
                value: controller.strokeWidth.value,
                min: 2,
                    max: 30,
                    onChanged: controller.setStrokeWidth,
                  ),
                  const SizedBox(height: 4),
                  Text('Opacity: ${(controller.strokeOpacity.value * 100).round()}%'),
                  Slider(
                    value: controller.strokeOpacity.value,
                    min: 0.1,
                    max: 1,
                    onChanged: controller.setStrokeOpacity,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: colors
                        .map(
                          (c) => GestureDetector(
                            onTap: () => controller.setStrokeColor(c),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c,
                                border: Border.all(
                                  color: controller.strokeColor.value == c
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          controller.undoStroke();
                        },
                        child: const Text('Undo Stroke'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: controller.clearStrokes,
                        child: const Text('Clear'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
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

  void _openLayersSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Obx(() {
              final texts = controller.texts.toList();
              final stickers = controller.stickers.toList();
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Layers', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text('Stickers', style: Theme.of(context).textTheme.bodySmall),
                  ...stickers.map((s) {
                    final selected = controller.activeStickerId.value == s.id;
                    return ListTile(
                      dense: true,
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              s.hidden ? Icons.visibility_off : Icons.visibility,
                              size: 18,
                            ),
                            onPressed: () => controller.toggleStickerHidden(s.id),
                          ),
                          IconButton(
                            icon: Icon(
                              s.locked ? Icons.lock : Icons.lock_open,
                              size: 18,
                            ),
                            onPressed: () => controller.toggleStickerLocked(s.id),
                          ),
                        ],
                      ),
                      title: Text('Sticker ${s.id}'),
                      trailing: selected ? const Icon(Icons.check) : null,
                      onTap: () => controller.setActiveSticker(s.id),
                    );
                  }),
                  const SizedBox(height: 8),
                  Text('Text', style: Theme.of(context).textTheme.bodySmall),
                  ...texts.map((t) {
                    final selected = controller.activeTextId.value == t.id;
                    return ListTile(
                      dense: true,
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              t.hidden ? Icons.visibility_off : Icons.visibility,
                              size: 18,
                            ),
                            onPressed: () => controller.toggleTextHidden(t.id),
                          ),
                          IconButton(
                            icon: Icon(
                              t.locked ? Icons.lock : Icons.lock_open,
                              size: 18,
                            ),
                            onPressed: () => controller.toggleTextLocked(t.id),
                          ),
                        ],
                      ),
                      title: Text(t.text, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: selected ? const Icon(Icons.check) : null,
                      onTap: () => controller.setActiveText(t.id),
                    );
                  }),
                  const SizedBox(height: 8),
                  Text('Strokes', style: Theme.of(context).textTheme.bodySmall),
                  ...controller.strokes.map((s) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.edit),
                      title: Text('Stroke ${s.id}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => controller.deleteStroke(s.id),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: controller.activeStickerId.value != null
                            ? controller.bringActiveStickerToFront
                            : controller.bringActiveTextToFront,
                        child: const Text('Bring to Front'),
                      ),
                      OutlinedButton(
                        onPressed: controller.activeStickerId.value != null
                            ? controller.bringActiveStickerToBack
                            : controller.bringActiveTextToBack,
                        child: const Text('Send to Back'),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          if (controller.activeStickerId.value != null) {
                            controller.removeActiveSticker();
                          } else if (controller.activeTextId.value != null) {
                            controller.removeActiveText();
                          }
                        },
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  void _openShapesSheet(BuildContext context) {
    final colors = <Color>[
      Colors.white,
      Colors.black,
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.amber,
      Colors.purple,
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        Color selected = colors.first;
        double size = 80;
        EditorStickerKind kind = EditorStickerKind.rect;
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Shapes', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Rect'),
                          selected: kind == EditorStickerKind.rect,
                          onSelected: (_) => setState(() => kind = EditorStickerKind.rect),
                        ),
                        ChoiceChip(
                          label: const Text('Circle'),
                          selected: kind == EditorStickerKind.circle,
                          onSelected: (_) => setState(() => kind = EditorStickerKind.circle),
                        ),
                        ChoiceChip(
                          label: const Text('Arrow'),
                          selected: kind == EditorStickerKind.arrow,
                          onSelected: (_) => setState(() => kind = EditorStickerKind.arrow),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Size: ${size.round()}'),
                    Slider(
                      value: size,
                      min: 40,
                      max: 200,
                      onChanged: (v) => setState(() => size = v),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: colors
                          .map(
                            (c) => GestureDetector(
                              onTap: () => setState(() => selected = c),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: c,
                                  border: Border.all(
                                    color: selected == c
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        controller.addShape(
                          kind: kind,
                          baseSize: size,
                          color: selected,
                        );
                        Navigator.of(context).pop();
                      },
                      child: const Text('Add Shape'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _askForEmoji(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Emoji Sticker'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Type/paste an emoji',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _promptForText(BuildContext context, String title) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _openRemoveBgSheet(BuildContext context) {
    double threshold = 18;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Background Removal',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Text('Threshold: ${threshold.round()}'),
                    Slider(
                      value: threshold,
                      min: 5,
                      max: 60,
                      onChanged: (v) => setState(() => threshold = v),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: controller.removeBgBusy.value
                          ? null
                          : () async {
                              await controller.removeBackgroundWithThreshold(
                                threshold: threshold.round(),
                              );
                              if (context.mounted) Navigator.of(context).pop();
                            },
                      child: Obx(() => Text(
                          controller.removeBgBusy.value ? 'Working...' : 'Apply')),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor'),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: controller.undo,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: controller.redo,
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            tooltip: 'Replace photo',
            onPressed: () => _openReplaceSheet(context),
            icon: const Icon(Icons.image_outlined),
          ),
          IconButton(
            tooltip: 'Theme',
            onPressed: () {
              final theme = Get.find<ThemeController>();
              theme.toggleMode();
            },
            icon: const Icon(Icons.brightness_6),
          ),
        ],
      ),
      body: Center(
        child: Obx(() {
          final path = controller.imagePath.value;
          final stickers = controller.stickers.toList();
          final texts = controller.texts.toList();
          if (path == null || path.isEmpty) {
            return const Text('No image selected');
          }

          final matrix = controller.currentColorMatrix();
          final image = Image.file(File(path));
          final basePreview = matrix == null
              ? image
              : ColorFiltered(
                  colorFilter: ColorFilter.matrix(matrix),
                  child: image,
                );

          final preview = Obx(() {
            final blur = controller.blur.value * 20;
            final flipX = controller.flipX.value ? -1.0 : 1.0;
            final rot = controller.rotationQuarter.value * (math.pi / 2);
            final transform = Matrix4.diagonal3Values(flipX, 1, 1)
              ..rotateZ(rot)
              ..setEntry(0, 1, controller.skewX.value)
              ..setEntry(1, 0, controller.skewY.value);
            return Transform(
              alignment: Alignment.center,
              transform: transform,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: basePreview,
              ),
            );
          });

          return Padding(
            padding: EdgeInsets.all(4.w),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return RepaintBoundary(
                  key: _previewKey,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: controller.clearSelections,
                        onPanStart: (d) {
                          if (!controller.isDrawing) return;
                          controller.beginStroke(d.localPosition);
                        },
                        onPanUpdate: (d) {
                          if (!controller.isDrawing) return;
                          controller.appendStroke(d.localPosition);
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            preview,
                            Obx(() {
                              if (controller.isCapturing.value) {
                                return const SizedBox.shrink();
                              }
                              final tmpl = controller
                                  .templates[controller.selectedTemplateIndex.value];
                              final ratio = tmpl.aspectRatio;
                              if (ratio == null) return const SizedBox.shrink();

                              final maxW = constraints.maxWidth;
                              final maxH = constraints.maxHeight;
                              double w = maxW;
                              double h = w / ratio;
                              if (h > maxH) {
                                h = maxH;
                                w = h * ratio;
                              }
                              return IgnorePointer(
                                child: Align(
                                  child: Container(
                                    width: w,
                                    height: h,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.6),
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            Obx(() {
                              if (controller.isCapturing.value) {
                                return const SizedBox.shrink();
                              }
                              final strength = controller.vignette.value;
                              if (strength <= 0) return const SizedBox.shrink();
                              return IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.55 * strength),
                                      ],
                                      stops: const [0.6, 1.0],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            ...stickers.map((s) {
                              if (s.hidden) return const SizedBox.shrink();
                              final left =
                                  (s.dx * constraints.maxWidth) -
                                  (s.baseSize * s.scale / 2);
                              final top =
                                  (s.dy * constraints.maxHeight) -
                                  (s.baseSize * s.scale / 2);
                              return Positioned(
                                left: left,
                                top: top,
                                child: _StickerOverlay(
                                  sticker: s,
                                  isSelected:
                                      controller.activeStickerId.value == s.id,
                                  onTap: () => controller.setActiveSticker(s.id),
                                  onTransform: (delta, scale, rotation) {
                                    if (controller.activeStickerId.value != s.id) {
                                      return;
                                    }
                                    controller.updateStickerTransform(
                                      id: s.id,
                                      dx: s.dx + delta.dx / constraints.maxWidth,
                                      dy: s.dy + delta.dy / constraints.maxHeight,
                                      scale: scale,
                                      rotation: rotation,
                                    );
                                  },
                                ),
                              );
                            }),
                            ...texts.map((t) {
                              if (t.hidden) return const SizedBox.shrink();
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
                                    child: _StyledText(t: t),
                                  );
                                }),
                              ),
                            );
                          }),
                            Obx(() {
                              final strokes = controller.strokes.toList();
                              if (strokes.isEmpty) return const SizedBox.shrink();
                              return IgnorePointer(
                                child: CustomPaint(
                                  painter: _StrokePainter(strokes),
                                  size: Size(
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
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
          padding: EdgeInsets.symmetric(vertical: 1.2.h, horizontal: 1.5.w),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 1.5.w),
            child: Row(
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
                  icon: Icons.settings_brightness,
                  label: 'Adjust',
                  onTap: () => _openAdjustmentsSheet(context),
                ),
                _EditorOption(
                  icon: Icons.text_fields,
                  label: 'Text',
                  onTap: () {
                    _openTextSheet(context);
                  },
                ),
                _EditorOption(
                  icon: Icons.emoji_emotions_outlined,
                  label: 'Sticker',
                  onTap: () => _openStickersSheet(context),
                ),
                _EditorOption(
                  icon: Icons.category_outlined,
                  label: 'Shapes',
                  onTap: () => _openShapesSheet(context),
                ),
                _EditorOption(
                  icon: Icons.crop_16_9,
                  label: 'Template',
                  onTap: () => _openTemplateSheet(context),
                ),
                _EditorOption(
                  icon: Icons.rotate_90_degrees_ccw,
                  label: 'Rotate',
                  onTap: () => controller.rotateQuarterTurns(1),
                ),
                _EditorOption(
                  icon: Icons.flip,
                  label: 'Flip',
                  onTap: controller.toggleFlipX,
                ),
                _EditorOption(
                  icon: Icons.layers,
                  label: 'Layers',
                  onTap: () => _openLayersSheet(context),
                ),
                _EditorOption(
                  icon: Icons.brush,
                  label: controller.isDrawing ? 'Draw On' : 'Brush',
                  onTap: () => _openBrushSheet(context),
                ),
                _EditorOption(
                  icon: Icons.save_alt,
                  label: 'Save',
                  onTap: () => _openExportSheet(context),
                ),
              ]
                  .map(
                    (w) => Padding(
                      padding: EdgeInsets.symmetric(horizontal: 1.2.w),
                      child: w,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _openReplaceSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Replace Photo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    controller.replaceImage(ImageSource.gallery);
                  },
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Pick from Gallery'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    controller.replaceImage(ImageSource.camera);
                  },
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Capture from Camera'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdjustmentSlider extends StatelessWidget {
  const _AdjustmentSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$label: ${value.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _StrokePainter extends CustomPainter {
  const _StrokePainter(this.strokes);

  final List<EditorStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = stroke.color.withValues(alpha: stroke.opacity)
        ..strokeWidth = stroke.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) =>
      oldDelegate.strokes != strokes;
}

class _ColorPickerRow extends StatelessWidget {
  const _ColorPickerRow({required this.selected, required this.onSelect});

  final Color selected;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = <Color>[
      Colors.white,
      Colors.black,
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.amber,
      Colors.purple,
      Colors.cyan,
    ];
    return Wrap(
      spacing: 8,
      children: colors
          .map(
            (c) => GestureDetector(
              onTap: () => onSelect(c),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c,
                  border: Border.all(
                    color: selected == c
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StickerOverlay extends StatefulWidget {
  const _StickerOverlay({
    required this.sticker,
    required this.isSelected,
    required this.onTap,
    required this.onTransform,
  });

  final EditorSticker sticker;
  final bool isSelected;
  final VoidCallback onTap;
  final void Function(Offset delta, double scale, double rotation) onTransform;

  @override
  State<_StickerOverlay> createState() => _StickerOverlayState();
}

class _StickerOverlayState extends State<_StickerOverlay> {
  double _startScale = 1.0;
  double _startRotation = 0.0;

  @override
  void didUpdateWidget(covariant _StickerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sticker.id != widget.sticker.id) {
      _startScale = 1.0;
      _startRotation = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sticker;
    Widget child;
    switch (s.kind) {
      case EditorStickerKind.emoji:
        child = Text(
          s.data,
          style: TextStyle(fontSize: s.baseSize, height: 1, color: s.color),
        );
        break;
      case EditorStickerKind.rect:
        child = Container(
          width: s.baseSize,
          height: s.baseSize,
          color: s.color,
        );
        break;
      case EditorStickerKind.circle:
        child = Container(
          width: s.baseSize,
          height: s.baseSize,
          decoration: BoxDecoration(
            color: s.color,
            shape: BoxShape.circle,
          ),
        );
        break;
      case EditorStickerKind.arrow:
        child = Icon(
          Icons.arrow_upward,
          size: s.baseSize,
          color: s.color,
        );
        break;
    }

    return GestureDetector(
      onTap: widget.onTap,
      onScaleStart: (_) {
        _startScale = s.scale;
        _startRotation = s.rotation;
      },
      onScaleUpdate: (d) {
        widget.onTransform(
          d.focalPointDelta,
          _startScale * d.scale,
          _startRotation + d.rotation,
        );
      },
      child: Transform.rotate(
        angle: s.rotation,
        child: Transform.scale(
          scale: s.scale,
          alignment: Alignment.topLeft,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: widget.isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
              color: widget.isSelected
                  ? Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            child: child,
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

class _StyledText extends StatelessWidget {
  const _StyledText({required this.t});

  final EditorText t;

  TextStyle _baseStyle() {
    final shadows = <Shadow>[];
    if (t.shadow) {
      shadows.add(
        Shadow(
          offset: const Offset(2, 2),
          blurRadius: 4,
          color: Colors.black.withValues(alpha: 0.55),
        ),
      );
    }
    if (t.glow) {
      shadows.add(
        Shadow(
          offset: Offset.zero,
          blurRadius: 18,
          color: t.color.withValues(alpha: 0.8),
        ),
      );
    }

    TextStyle base = TextStyle(
      color: t.color,
      fontSize: t.fontSize,
      height: 1.1,
      shadows: shadows,
    );

    try {
      base = GoogleFonts.getFont(t.font, textStyle: base);
    } catch (_) {
      // fallback silently
    }
    return base;
  }

  TextStyle _outlineStyle() {
    final outlineColor =
        t.color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    TextStyle stroke = TextStyle(
      fontSize: t.fontSize,
      height: 1.1,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = t.outline.clamp(0.0, 8.0)
        ..color = outlineColor.withValues(alpha: 0.9),
    );
    try {
      stroke = GoogleFonts.getFont(t.font, textStyle: stroke);
    } catch (_) {}
    return stroke;
  }

  @override
  Widget build(BuildContext context) {
    final fill = _baseStyle();
    final outline = t.outline > 0 ? _outlineStyle() : null;

    if (t.curved) {
      return _CurvedText(
        text: t.text,
        fillStyle: fill,
        outlineStyle: outline,
        radius: t.curveRadius,
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        if (outline != null) Text(t.text, style: outline),
        Text(t.text, style: fill),
      ],
    );
  }
}

class _CurvedText extends StatelessWidget {
  const _CurvedText({
    required this.text,
    required this.fillStyle,
    required this.radius,
    this.outlineStyle,
  });

  final String text;
  final TextStyle fillStyle;
  final TextStyle? outlineStyle;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2 + (fillStyle.fontSize ?? 16) * 0.6;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CurvedTextPainter(
          text: text,
          fillStyle: fillStyle,
          outlineStyle: outlineStyle,
          radius: radius,
        ),
      ),
    );
  }
}

class _CurvedTextPainter extends CustomPainter {
  const _CurvedTextPainter({
    required this.text,
    required this.fillStyle,
    required this.radius,
    this.outlineStyle,
  });

  final String text;
  final TextStyle fillStyle;
  final TextStyle? outlineStyle;
  final double radius;

  TextPainter _painterFor(String char, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: char, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final totalAngle = math.pi; // 180 deg arc
    double currentAngle = -totalAngle / 2;

    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      final fillPainter = _painterFor(char, fillStyle);
      final outlinePainter =
          outlineStyle != null ? _painterFor(char, outlineStyle!) : null;

      final charAngle = (fillPainter.width / radius).clamp(0.01, 0.6);
      final midAngle = currentAngle + charAngle / 2;
      final offset = Offset(
        center.dx + radius * math.cos(midAngle),
        center.dy + radius * math.sin(midAngle),
      );

      void paintPainter(TextPainter p) {
        canvas.save();
        canvas.translate(offset.dx, offset.dy);
        canvas.rotate(midAngle + math.pi / 2);
        p.paint(
          canvas,
          Offset(-p.width / 2, -p.height / 2),
        );
        canvas.restore();
      }

      if (outlinePainter != null) paintPainter(outlinePainter);
      paintPainter(fillPainter);
      currentAngle += charAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _CurvedTextPainter oldDelegate) {
    return text != oldDelegate.text ||
        fillStyle != oldDelegate.fillStyle ||
        outlineStyle != oldDelegate.outlineStyle ||
        radius != oldDelegate.radius;
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
