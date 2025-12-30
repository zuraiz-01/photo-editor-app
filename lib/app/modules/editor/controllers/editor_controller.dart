import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/material.dart';

class EditorController extends GetxController {
  final imagePath = RxnString();
  final isCropping = false.obs;

  final presets = <List<double>>[];
  final selectedPresetIndex = 0.obs;
  final filterIntensity = 1.0.obs;

  final texts = <EditorText>[].obs;
  final activeTextId = RxnInt();
  int _nextTextId = 1;

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

  // Index 0 is treated as "None" (identity -> return null)
  out.add(_identity);

  // Core presets
  out.add(_grayscale);
  out.add(_sepia);
  out.add(_invert);

  // Variants: warm/cool (tint), vivid (saturation-ish), fade, brighten, contrast.
  // We generate enough presets to exceed 50.
  for (var i = 0; i < 12; i++) {
    final t = i / 11.0; // 0..1
    out.add(_tintMatrix(r: 1.0 + 0.25 * t, g: 1.0, b: 1.0 - 0.20 * t)); // warm
  }
  for (var i = 0; i < 12; i++) {
    final t = i / 11.0;
    out.add(_tintMatrix(r: 1.0 - 0.20 * t, g: 1.0, b: 1.0 + 0.25 * t)); // cool
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
  // Pivot around 128
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
