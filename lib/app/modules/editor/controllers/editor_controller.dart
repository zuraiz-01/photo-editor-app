import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class EditorController extends GetxController {
  final imagePath = RxnString();
  final isCropping = false.obs;
  final isSaving = false.obs;

  final presets = <List<double>>[];
  final selectedPresetIndex = 0.obs;
  final filterIntensity = 1.0.obs;

  final texts = <EditorText>[].obs;
  final activeTextId = RxnInt();
  int _nextTextId = 1;

  final stickers = <EditorSticker>[].obs;
  final activeStickerId = RxnInt();
  int _nextStickerId = 1;

  final draftText = ''.obs;
  final draftColor = Colors.white.obs;
  final draftFontSize = 28.0.obs;

  @override
  void onInit() {
    super.onInit();
    presets.addAll(_buildPresets());
    final arg = Get.arguments;
    if (arg is String && arg.isNotEmpty) {
      imagePath.value = arg;
    }
  }

  void clearSelections() {
    activeTextId.value = null;
    activeStickerId.value = null;
  }

  Future<void> saveToGallery(Uint8List pngBytes) async {
    if (isSaving.value) return;
    isSaving.value = true;
    try {
      if (Platform.isIOS) {
        final status = await Permission.photosAddOnly.request();
        if (!status.isGranted) {
          Get.snackbar('Save', 'Permission denied');
          return;
        }
      } else if (Platform.isAndroid) {
        final photos = await Permission.photos.request();
        final storage = await Permission.storage.request();
        if (!photos.isGranted && !storage.isGranted) {
          Get.snackbar('Save', 'Permission denied');
          return;
        }
      }

      final name = 'photo_editor_${DateTime.now().millisecondsSinceEpoch}';
      final result = await ImageGallerySaverPlus.saveImage(
        pngBytes,
        quality: 100,
        name: name,
      );

      final success =
          (result is Map &&
          (result['isSuccess'] == true || result['isSuccess'] == 1));
      if (success) {
        Get.snackbar('Save', 'Saved to gallery');
      } else {
        Get.snackbar('Save', 'Save failed');
      }
    } catch (e) {
      Get.snackbar('Save failed', e.toString());
    } finally {
      isSaving.value = false;
    }
  }

  int addText({
    required String text,
    Color color = Colors.white,
    double fontSize = 28,
  }) {
    final id = _nextTextId++;
    texts.add(
      EditorText(
        id: id,
        text: text,
        color: color,
        fontSize: fontSize,
        dx: 0.5,
        dy: 0.5,
      ),
    );
    activeTextId.value = id;
    return id;
  }

  void setActiveText(int? id) {
    activeTextId.value = id;
    if (id != null) activeStickerId.value = null;
  }

  void beginTextEditing({int? id}) {
    if (id != null) {
      activeTextId.value = id;
    }
    final current = activeText;
    draftText.value = current?.text ?? '';
    draftColor.value = current?.color ?? Colors.white;
    draftFontSize.value = current?.fontSize ?? 28.0;
  }

  void setDraftText(String value) {
    draftText.value = value;
  }

  void setDraftColor(Color color) {
    draftColor.value = color;
  }

  void setDraftFontSize(double size) {
    draftFontSize.value = size;
  }

  void commitDraftText() {
    final value = draftText.value.trim();
    if (value.isEmpty) return;

    final id = activeTextId.value;
    if (id == null) {
      addText(
        text: value,
        color: draftColor.value,
        fontSize: draftFontSize.value,
      );
      return;
    }
    updateActiveText(
      text: value,
      color: draftColor.value,
      fontSize: draftFontSize.value,
    );
  }

  EditorText? get activeText {
    final id = activeTextId.value;
    if (id == null) return null;
    return texts.firstWhereOrNull((e) => e.id == id);
  }

  void updateActiveText({String? text, Color? color, double? fontSize}) {
    final current = activeText;
    if (current == null) return;
    final index = texts.indexWhere((e) => e.id == current.id);
    if (index < 0) return;
    texts[index] = current.copyWith(
      text: text,
      color: color,
      fontSize: fontSize,
    );
  }

  void removeActiveText() {
    final id = activeTextId.value;
    if (id == null) return;
    texts.removeWhere((e) => e.id == id);
    activeTextId.value = null;
  }

  void moveTextByDelta({
    required int id,
    required double dx,
    required double dy,
  }) {
    final index = texts.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final item = texts[index];
    final nextDx = (item.dx + dx).clamp(0.0, 1.0);
    final nextDy = (item.dy + dy).clamp(0.0, 1.0);
    texts[index] = item.copyWith(dx: nextDx, dy: nextDy);
  }

  int addEmojiSticker({required String emoji, double baseSize = 64}) {
    final value = emoji.trim();
    if (value.isEmpty) return -1;

    final id = _nextStickerId++;
    stickers.add(
      EditorSticker(
        id: id,
        kind: EditorStickerKind.emoji,
        data: value,
        dx: 0.5,
        dy: 0.5,
        scale: 1.0,
        rotation: 0.0,
        baseSize: baseSize,
      ),
    );
    activeStickerId.value = id;
    activeTextId.value = null;
    return id;
  }

  void setActiveSticker(int? id) {
    activeStickerId.value = id;
    if (id != null) activeTextId.value = null;
  }

  EditorSticker? get activeSticker {
    final id = activeStickerId.value;
    if (id == null) return null;
    return stickers.firstWhereOrNull((e) => e.id == id);
  }

  void removeActiveSticker() {
    final id = activeStickerId.value;
    if (id == null) return;
    stickers.removeWhere((e) => e.id == id);
    activeStickerId.value = null;
  }

  void bringActiveStickerToFront() {
    final current = activeSticker;
    if (current == null) return;
    final index = stickers.indexWhere((e) => e.id == current.id);
    if (index < 0) return;
    stickers.removeAt(index);
    stickers.add(current);
  }

  void updateStickerTransform({
    required int id,
    double? dx,
    double? dy,
    double? scale,
    double? rotation,
  }) {
    final index = stickers.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final item = stickers[index];
    stickers[index] = item.copyWith(
      dx: (dx ?? item.dx).clamp(0.0, 1.0),
      dy: (dy ?? item.dy).clamp(0.0, 1.0),
      scale: (scale ?? item.scale).clamp(0.2, 8.0),
      rotation: rotation ?? item.rotation,
    );
  }

  Future<void> cropImage() async {
    final path = imagePath.value;
    if (path == null || path.isEmpty) return;

    if (isCropping.value) return;
    isCropping.value = true;
    Get.snackbar('Crop', 'Opening cropper...');
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 95,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop',
            lockAspectRatio: false,
            hideBottomControls: false,
          ),
          IOSUiSettings(title: 'Crop'),
        ],
      );

      if (cropped == null) {
        Get.snackbar('Crop', 'No changes applied');
        return;
      }
      imagePath.value = cropped.path;
      Get.snackbar('Crop', 'Applied');
    } catch (e) {
      Get.snackbar('Crop failed', e.toString());
    } finally {
      isCropping.value = false;
    }
  }

  void setPreset(int index) {
    if (index < 0 || index >= presets.length) return;
    selectedPresetIndex.value = index;
  }

  void setFilterIntensity(double value) {
    filterIntensity.value = value.clamp(0.0, 1.0);
  }

  List<double>? matrixForPreset(int index, double intensity) {
    if (index <= 0) return null;
    if (index >= presets.length) return null;
    return _lerpMatrix(_identity, presets[index], intensity.clamp(0.0, 1.0));
  }

  List<double>? currentColorMatrix() {
    return matrixForPreset(selectedPresetIndex.value, filterIntensity.value);
  }
}

const List<double> _identity = <double>[
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

const List<double> _grayscale = <double>[
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

const List<double> _sepia = <double>[
  0.393,
  0.769,
  0.189,
  0,
  0,
  0.349,
  0.686,
  0.168,
  0,
  0,
  0.272,
  0.534,
  0.131,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

const List<double> _invert = <double>[
  -1,
  0,
  0,
  0,
  255,
  0,
  -1,
  0,
  0,
  255,
  0,
  0,
  -1,
  0,
  255,
  0,
  0,
  0,
  1,
  0,
];

List<List<double>> _buildPresets() {
  final out = <List<double>>[];

  // Index 0 treated as "None".
  out.add(_identity);
  out.add(_grayscale);
  out.add(_sepia);
  out.add(_invert);

  for (var i = 0; i < 12; i++) {
    final t = i / 11.0;
    out.add(_tintMatrix(r: 1.0 + 0.25 * t, g: 1.0, b: 1.0 - 0.20 * t));
  }
  for (var i = 0; i < 12; i++) {
    final t = i / 11.0;
    out.add(_tintMatrix(r: 1.0 - 0.20 * t, g: 1.0, b: 1.0 + 0.25 * t));
  }
  for (var i = 0; i < 12; i++) {
    final t = i / 11.0;
    out.add(_saturationBoost(1.0 + 0.7 * t));
  }
  for (var i = 0; i < 8; i++) {
    final t = i / 7.0;
    out.add(_fadeMatrix(0.95 - 0.25 * t, lift: (10 + 25 * t).roundToDouble()));
  }
  for (var i = 0; i < 8; i++) {
    final t = i / 7.0;
    out.add(_brightnessOffset((10 + 45 * t).roundToDouble()));
  }
  for (var i = 0; i < 8; i++) {
    final t = i / 7.0;
    out.add(_contrastMatrix(1.05 + 0.55 * t));
  }

  return out;
}

List<double> _tintMatrix({
  required double r,
  required double g,
  required double b,
}) {
  return <double>[r, 0, 0, 0, 0, 0, g, 0, 0, 0, 0, 0, b, 0, 0, 0, 0, 0, 1, 0];
}

List<double> _brightnessOffset(double offset) {
  return <double>[
    1,
    0,
    0,
    0,
    offset,
    0,
    1,
    0,
    0,
    offset,
    0,
    0,
    1,
    0,
    offset,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _contrastMatrix(double c) {
  final o = 128 * (1 - c);
  return <double>[c, 0, 0, 0, o, 0, c, 0, 0, o, 0, 0, c, 0, o, 0, 0, 0, 1, 0];
}

List<double> _fadeMatrix(double scale, {required double lift}) {
  return <double>[
    scale,
    0,
    0,
    0,
    lift,
    0,
    scale,
    0,
    0,
    lift,
    0,
    0,
    scale,
    0,
    lift,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _saturationBoost(double s) {
  final inv = 1 - s;
  const r = 0.2126;
  const g = 0.7152;
  const b = 0.0722;
  return <double>[
    inv * r + s,
    inv * g,
    inv * b,
    0,
    0,
    inv * r,
    inv * g + s,
    inv * b,
    0,
    0,
    inv * r,
    inv * g,
    inv * b + s,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _lerpMatrix(List<double> a, List<double> b, double t) {
  final out = List<double>.filled(20, 0);
  for (var i = 0; i < 20; i++) {
    out[i] = a[i] + (b[i] - a[i]) * t;
  }
  return out;
}

@immutable
class EditorText {
  const EditorText({
    required this.id,
    required this.text,
    required this.color,
    required this.fontSize,
    required this.dx,
    required this.dy,
  });

  final int id;
  final String text;
  final Color color;
  final double fontSize;
  final double dx;
  final double dy;

  EditorText copyWith({
    String? text,
    Color? color,
    double? fontSize,
    double? dx,
    double? dy,
  }) {
    return EditorText(
      id: id,
      text: text ?? this.text,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
    );
  }
}

enum EditorStickerKind { emoji }

@immutable
class EditorSticker {
  const EditorSticker({
    required this.id,
    required this.kind,
    required this.data,
    required this.dx,
    required this.dy,
    required this.scale,
    required this.rotation,
    required this.baseSize,
  });

  final int id;
  final EditorStickerKind kind;
  final String data;
  final double dx;
  final double dy;
  final double scale;
  final double rotation;
  final double baseSize;

  EditorSticker copyWith({
    double? dx,
    double? dy,
    double? scale,
    double? rotation,
  }) {
    return EditorSticker(
      id: id,
      kind: kind,
      data: data,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      baseSize: baseSize,
    );
  }
}
