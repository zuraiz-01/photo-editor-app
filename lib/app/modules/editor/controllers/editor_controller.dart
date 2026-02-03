import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class EditorController extends GetxController {
  final _picker = ImagePicker();
  final imagePath = RxnString();
  final isCropping = false.obs;
  final isSaving = false.obs;
  final isReplacing = false.obs;
  final isCapturing = false.obs;

  final presets = <List<double>>[];
  final selectedPresetIndex = 0.obs;
  final filterIntensity = 1.0.obs;
  final blur = 0.0.obs; // 0..1 -> sigma 0..20
  final vignette = 0.0.obs; // 0..1 strength

  // Adjustments
  final brightness = 0.0.obs; // -1..1 mapped to -60..60 offset
  final contrast = 0.0.obs; // -0.5..0.5 mapped to 0.5..1.5 scale
  final exposure = 0.0.obs; // -1..1 mapped to -80..80 offset
  final vibrance = 0.0.obs; // -1..1 mapped to 0..2 saturation
  final temperature = 0.0.obs; // -1..1 mapped to red/blue gain
  final removeBgBusy = false.obs;
  final frameEnabled = false.obs;
  final frameColor = Colors.white.obs;
  final frameWidth = 6.0.obs;
  final frameRadius = 16.0.obs;
  final safeAreaEnabled = false.obs;
  final safeAreaPresetIndex = 0.obs;
  final framePresetIndex = 0.obs;

  // Perspective / transform
  final flipX = false.obs;
  final rotationQuarter = 0.obs; // 0,1,2,3
  final skewX = 0.0.obs; // -0.5..0.5
  final skewY = 0.0.obs;

  final texts = <EditorText>[].obs;
  final activeTextId = RxnInt();
  int _nextTextId = 1;

  final stickers = <EditorSticker>[].obs;
  final activeStickerId = RxnInt();
  int _nextStickerId = 1;

  final strokes = <EditorStroke>[].obs;
  bool isDrawing = false;
  bool eraserMode = false;
  int _nextStrokeId = 1;
  final strokeColor = Colors.white.obs;
  final strokeWidth = 6.0.obs;
  final strokeOpacity = 0.8.obs;

  final draftText = ''.obs;
  final draftColor = Colors.white.obs;
  final draftFontSize = 28.0.obs;

  // Templates (aspect guides)
  final templates = <TemplateGuide>[
    const TemplateGuide(name: 'None', aspectRatio: null),
    const TemplateGuide(name: '1:1', aspectRatio: 1.0),
    const TemplateGuide(name: '4:5', aspectRatio: 4 / 5),
    const TemplateGuide(name: '9:16', aspectRatio: 9 / 16),
    const TemplateGuide(name: '16:9', aspectRatio: 16 / 9),
    const TemplateGuide(name: 'YouTube Thumb 16:9', aspectRatio: 16 / 9),
    const TemplateGuide(name: 'Story 9:16', aspectRatio: 9 / 16),
  ];
  final selectedTemplateIndex = 0.obs;
  final safeAreas = <SafeAreaGuide>[
    const SafeAreaGuide(name: 'None', left: 0, right: 0, top: 0, bottom: 0),
    const SafeAreaGuide(
      name: 'IG Story Safe',
      left: 0.05,
      right: 0.05,
      top: 0.12,
      bottom: 0.12,
    ),
    const SafeAreaGuide(
      name: 'IG Reel Safe',
      left: 0.05,
      right: 0.05,
      top: 0.07,
      bottom: 0.16,
    ),
    const SafeAreaGuide(
      name: 'YouTube Thumb Safe',
      left: 0.07,
      right: 0.07,
      top: 0.1,
      bottom: 0.1,
    ),
    const SafeAreaGuide(
      name: 'Twitter/X Feed',
      left: 0.04,
      right: 0.04,
      top: 0.08,
      bottom: 0.08,
    ),
    const SafeAreaGuide(
      name: 'TikTok Feed',
      left: 0.05,
      right: 0.05,
      top: 0.12,
      bottom: 0.16,
    ),
  ];

  // Undo / Redo
  final _undoStack = <EditorState>[];
  final _redoStack = <EditorState>[];
  DateTime? _lastSnapshotAt;
  final Duration _snapshotCooldown = const Duration(milliseconds: 250);
  bool _restoring = false;

  // User presets (saved adjustments/filters)
  final userPresets = <SavedPreset>[].obs;

  @override
  void onInit() {
    super.onInit();
    presets.addAll(_buildPresets());
    final arg = Get.arguments;
    if (arg is String && arg.isNotEmpty) {
      imagePath.value = arg;
    }
    _pushState(force: true, clearRedo: false);
  }

  void clearSelections() {
    activeTextId.value = null;
    activeStickerId.value = null;
  }

  Future<void> replaceImage(ImageSource source) async {
    if (isReplacing.value) return;
    isReplacing.value = true;
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;
      imagePath.value = picked.path;
      texts.clear();
      stickers.clear();
      clearSelections();
      Get.snackbar('Image', 'Replaced photo');
      _pushState();
    } on PlatformException catch (e) {
      if (e.code.contains('denied')) {
        final where = source == ImageSource.camera ? 'camera' : 'gallery';
        Get.snackbar('Permission needed', 'Please allow $where access.');
        return;
      }
      rethrow;
    } finally {
      isReplacing.value = false;
    }
  }

  Future<void> saveToGallery(
    Uint8List bytes, {
    ExportFormat format = ExportFormat.png,
    int quality = 100,
  }) async {
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

      final ext = format == ExportFormat.png ? 'png' : 'jpg';
      final name = 'photo_editor_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: quality,
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

  Future<void> removeBackground() async {
    await removeBackgroundWithThreshold(threshold: 18);
  }

  Future<void> removeBackgroundWithThreshold({
    required int threshold,
    Offset? samplePoint, // normalized 0-1
  }) async {
    if (removeBgBusy.value) return;
    final path = imagePath.value;
    if (path == null || path.isEmpty) return;
    removeBgBusy.value = true;
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        Get.snackbar('Background', 'Unable to decode image');
        return;
      }
      int sx = 0;
      int sy = 0;
      if (samplePoint != null) {
        sx = (samplePoint.dx.clamp(0, 1) * (decoded.width - 1)).round();
        sy = (samplePoint.dy.clamp(0, 1) * (decoded.height - 1)).round();
      }
      final ref = decoded.getPixel(sx, sy);
      final r0 = ref.r;
      final g0 = ref.g;
      final b0 = ref.b;
      for (var y = 0; y < decoded.height; y++) {
        for (var x = 0; x < decoded.width; x++) {
          final p = decoded.getPixel(x, y);
          if ((p.r - r0).abs() < threshold &&
              (p.g - g0).abs() < threshold &&
              (p.b - b0).abs() < threshold) {
            decoded.setPixelRgba(x, y, 0, 0, 0, 0);
          }
        }
      }
      final outBytes = Uint8List.fromList(img.encodePng(decoded));
      final dir = await getTemporaryDirectory();
      final outPath =
          '${dir.path}/removed_bg_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(outPath).writeAsBytes(outBytes);
      imagePath.value = outPath;
      _pushState();
      Get.snackbar('Background', 'Background removed (simple)');
    } catch (e) {
      Get.snackbar('Background', 'Failed: $e');
    } finally {
      removeBgBusy.value = false;
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
    _pushState();
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
    _pushState();
  }

  void removeActiveText() {
    final id = activeTextId.value;
    if (id == null) return;
    texts.removeWhere((e) => e.id == id);
    activeTextId.value = null;
    _pushState();
  }

  void moveTextByDelta({
    required int id,
    required double dx,
    required double dy,
  }) {
    final index = texts.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final item = texts[index];
    if (item.locked) return;
    final nextDx = (item.dx + dx).clamp(0.0, 1.0);
    final nextDy = (item.dy + dy).clamp(0.0, 1.0);
    texts[index] = item.copyWith(dx: nextDx, dy: nextDy);
    _pushState();
  }

  int addEmojiSticker({required String emoji, double baseSize = 64}) {
    return addSticker(
      kind: EditorStickerKind.emoji,
      data: emoji.trim(),
      baseSize: baseSize,
      color: Colors.white,
    );
  }

  int addShape({
    required EditorStickerKind kind,
    double baseSize = 80,
    Color color = Colors.white,
  }) {
    return addSticker(
      kind: kind,
      data: '',
      baseSize: baseSize,
      color: color,
    );
  }

  int addSticker({
    required EditorStickerKind kind,
    required String data,
    required double baseSize,
    required Color color,
  }) {
    final id = _nextStickerId++;
    stickers.add(
      EditorSticker(
        id: id,
        kind: kind,
        data: data,
        color: color,
        dx: 0.5,
        dy: 0.5,
        scale: 1.0,
        rotation: 0.0,
        baseSize: baseSize,
      ),
    );
    activeStickerId.value = id;
    activeTextId.value = null;
    _pushState();
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
    _pushState();
  }

  void bringActiveStickerToFront() {
    final current = activeSticker;
    if (current == null) return;
    final index = stickers.indexWhere((e) => e.id == current.id);
    if (index < 0) return;
    stickers.removeAt(index);
    stickers.add(current);
    _pushState();
  }

  void bringActiveStickerToBack() {
    final current = activeSticker;
    if (current == null) return;
    final index = stickers.indexWhere((e) => e.id == current.id);
    if (index < 0) return;
    stickers.removeAt(index);
    stickers.insert(0, current);
    _pushState();
  }

  void bringActiveTextToFront() {
    final current = activeText;
    if (current == null) return;
    final index = texts.indexWhere((e) => e.id == current.id);
    if (index < 0) return;
    texts.removeAt(index);
    texts.add(current);
    _pushState();
  }

  void bringActiveTextToBack() {
    final current = activeText;
    if (current == null) return;
    final index = texts.indexWhere((e) => e.id == current.id);
    if (index < 0) return;
    texts.removeAt(index);
    texts.insert(0, current);
    _pushState();
  }

  void toggleStickerHidden(int id) {
    final index = stickers.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final s = stickers[index];
    stickers[index] = s.copyWith(hidden: !s.hidden);
    _pushState();
  }

  void toggleStickerLocked(int id) {
    final index = stickers.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final s = stickers[index];
    stickers[index] = s.copyWith(locked: !s.locked);
    _pushState();
  }

  void toggleTextHidden(int id) {
    final index = texts.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final t = texts[index];
    texts[index] = t.copyWith(hidden: !t.hidden);
    _pushState();
  }

  void toggleTextLocked(int id) {
    final index = texts.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final t = texts[index];
    texts[index] = t.copyWith(locked: !t.locked);
    _pushState();
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
    if (item.locked) return;
    stickers[index] = item.copyWith(
      dx: (dx ?? item.dx).clamp(0.0, 1.0),
      dy: (dy ?? item.dy).clamp(0.0, 1.0),
      scale: (scale ?? item.scale).clamp(0.2, 8.0),
      rotation: rotation ?? item.rotation,
      color: item.color,
    );
    _pushState();
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
      _pushState();
    } catch (e) {
      Get.snackbar('Crop failed', e.toString());
    } finally {
      isCropping.value = false;
    }
  }

  void setPreset(int index) {
    if (index < 0 || index >= presets.length) return;
    selectedPresetIndex.value = index;
    _pushState();
  }

  void setFilterIntensity(double value) {
    filterIntensity.value = value.clamp(0.0, 1.0);
    _pushState();
  }

  void setBlur(double value) {
    blur.value = value.clamp(0.0, 1.0);
    _pushState();
  }

  void setVignette(double value) {
    vignette.value = value.clamp(0.0, 1.0);
    _pushState();
  }

  void setFrameEnabled(bool value) {
    frameEnabled.value = value;
    _pushState();
  }

  void setFrameColor(Color value) {
    frameColor.value = value;
    _pushState();
  }

  void setFrameWidth(double value) {
    frameWidth.value = value.clamp(1.0, 40.0);
    _pushState();
  }

  void setFrameRadius(double value) {
    frameRadius.value = value.clamp(0.0, 80.0);
    _pushState();
  }

  void setSafeAreaEnabled(bool value) {
    safeAreaEnabled.value = value;
    _pushState();
  }

  void setSafeAreaPreset(int index) {
    if (index < 0 || index >= safeAreas.length) return;
    safeAreaPresetIndex.value = index;
    safeAreaEnabled.value = index != 0;
    _pushState();
  }

  void applyFramePreset(int index) {
    framePresetIndex.value = index;
    switch (index) {
      case 0: // None
        frameEnabled.value = false;
        break;
      case 1: // Clean white
        frameEnabled.value = true;
        frameColor.value = Colors.white;
        frameWidth.value = 6;
        frameRadius.value = 18;
        break;
      case 2: // Minimal black
        frameEnabled.value = true;
        frameColor.value = Colors.black;
        frameWidth.value = 8;
        frameRadius.value = 10;
        break;
      case 3: // Gold rounded
        frameEnabled.value = true;
        frameColor.value = const Color(0xFFFFD54F);
        frameWidth.value = 10;
        frameRadius.value = 24;
        break;
      case 4: // Thin neon
        frameEnabled.value = true;
        frameColor.value = const Color(0xFF00E5FF);
        frameWidth.value = 4;
        frameRadius.value = 14;
        break;
      default:
        frameEnabled.value = false;
    }
    _pushState();
  }

  void setBrightness(double value) {
    brightness.value = value.clamp(-1.0, 1.0);
    _pushState();
  }

  void setContrast(double value) {
    contrast.value = value.clamp(-0.5, 0.5);
    _pushState();
  }

  void setExposure(double value) {
    exposure.value = value.clamp(-1.0, 1.0);
    _pushState();
  }

  void setVibrance(double value) {
    vibrance.value = value.clamp(-1.0, 1.0);
    _pushState();
  }

  void setTemperature(double value) {
    temperature.value = value.clamp(-1.0, 1.0);
    _pushState();
  }

  void resetAdjustments() {
    brightness.value = 0;
    contrast.value = 0;
    exposure.value = 0;
    vibrance.value = 0;
    temperature.value = 0;
    blur.value = 0;
    vignette.value = 0;
    _pushState();
  }

  void saveUserPreset(String name) {
    final state = _snapshot();
    userPresets.add(SavedPreset(name: name, state: state));
    _pushState();
  }

  void applyUserPreset(int index) {
    if (index < 0 || index >= userPresets.length) return;
    _applyState(userPresets[index].state);
    _pushState();
  }

  void renamePreset(int index, String name) {
    if (index < 0 || index >= userPresets.length) return;
    final preset = userPresets[index];
    userPresets[index] = SavedPreset(name: name, state: preset.state);
  }

  void deletePreset(int index) {
    if (index < 0 || index >= userPresets.length) return;
    userPresets.removeAt(index);
  }

  void setTemplate(int index) {
    if (index < 0 || index >= templates.length) return;
    selectedTemplateIndex.value = index;
    _pushState();
  }

  void setSkewX(double value) {
    skewX.value = value.clamp(-0.5, 0.5);
    _pushState();
  }

  void setSkewY(double value) {
    skewY.value = value.clamp(-0.5, 0.5);
    _pushState();
  }

  void resetPerspective() {
    skewX.value = 0;
    skewY.value = 0;
    _pushState();
  }

  // Brush / strokes
  void beginStroke(Offset point) {
    if (!isDrawing) return;
    if (eraserMode) {
      _eraseAt(point);
      return;
    }
    final id = _nextStrokeId++;
    strokes.add(
      EditorStroke(
        id: id,
        points: [point],
        color: strokeColor.value,
        width: strokeWidth.value,
        opacity: strokeOpacity.value,
      ),
    );
    _pushState();
  }

  void appendStroke(Offset point) {
    if (!isDrawing) return;
    if (eraserMode) {
      _eraseAt(point);
      return;
    }
    if (strokes.isEmpty) return;
    final last = strokes.last;
    final updated = last.copyWith(points: [...last.points, point]);
    strokes[strokes.length - 1] = updated;
    _pushState();
  }

  void undoStroke() {
    if (strokes.isEmpty) return;
    strokes.removeLast();
    _pushState();
  }

  void clearStrokes() {
    strokes.clear();
    _pushState();
  }

  void deleteStroke(int id) {
    strokes.removeWhere((e) => e.id == id);
    _pushState();
  }

  void setStrokeColor(Color c) {
    strokeColor.value = c;
  }

  void setStrokeWidth(double w) {
    strokeWidth.value = w.clamp(1.0, 40.0);
  }

  void setStrokeOpacity(double o) {
    strokeOpacity.value = o.clamp(0.1, 1.0);
  }

  void setEraserMode(bool value) {
    eraserMode = value;
  }

  void _eraseAt(Offset point) {
    const radius = 16.0;
    strokes.removeWhere((stroke) {
      for (final p in stroke.points) {
        if ((p - point).distance <= radius) return true;
      }
      return false;
    });
    _pushState();
  }

  void rotateQuarterTurns(int delta) {
    rotationQuarter.value = (rotationQuarter.value + delta) % 4;
    _pushState();
  }

  void toggleFlipX() {
    flipX.value = !flipX.value;
    _pushState();
  }

  List<double>? matrixForPreset(int index, double intensity) {
    if (index <= 0) return null;
    if (index >= presets.length) return null;
    return _lerpMatrix(_identity, presets[index], intensity.clamp(0.0, 1.0));
  }

  List<double>? currentColorMatrix() {
    final base =
        matrixForPreset(selectedPresetIndex.value, filterIntensity.value) ??
        _identity;
    return _applyAdjustments(base);
  }

  List<double> _applyAdjustments(List<double> base) {
    var m = base;
    final bOffset = brightness.value * 60;
    final expOffset = exposure.value * 80;
    final contrastScale = 1 + contrast.value; // 0.5..1.5
    final vibScale = (1 + vibrance.value * 1.2).clamp(0.0, 2.5);
    final tempVal = temperature.value;
    final tempR = 1 + 0.25 * tempVal;
    final tempB = 1 - 0.25 * tempVal;

    m = _composeMatrix(m, _brightnessOffset(bOffset + expOffset));
    m = _composeMatrix(m, _contrastMatrix(contrastScale));
    m = _composeMatrix(m, _saturationBoost(vibScale));
    m = _composeMatrix(m, _tintMatrix(r: tempR, g: 1.0, b: tempB));
    return m;
  }

  // Export helpers
  Future<Uint8List> convertBytes(
    Uint8List pngBytes, {
    required ExportFormat format,
    required int quality,
  }) async {
    if (format == ExportFormat.png) return pngBytes;
    final decoded = img.decodeImage(pngBytes);
    if (decoded == null) return pngBytes;
    return Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
  }

  Future<String?> shareBytes(
    Uint8List bytes, {
    required ExportFormat format,
  }) async {
    final dir = await getTemporaryDirectory();
    final ext = format == ExportFormat.png ? 'png' : 'jpg';
    final file =
        File('${dir.path}/share_${DateTime.now().millisecondsSinceEpoch}.$ext');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)]);
    return file.path;
  }

  Future<Uint8List> resizeBytes(Uint8List bytes, {int? maxWidth}) async {
    if (maxWidth == null) return bytes;
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    if (decoded.width <= maxWidth) return bytes;
    final resized = img.copyResize(decoded, width: maxWidth);
    return Uint8List.fromList(img.encodePng(resized));
  }

  // Undo / Redo
  bool get canUndo => _undoStack.length > 1;
  bool get canRedo => _redoStack.isNotEmpty;

  void undo() {
    if (!canUndo) return;
    final current = _undoStack.removeLast();
    _redoStack.add(current);
    final prev = _undoStack.last;
    _applyState(prev);
  }

  void redo() {
    if (!canRedo) return;
    final state = _redoStack.removeLast();
    _undoStack.add(state);
    _applyState(state);
  }

  void _applyState(EditorState state) {
    _restoring = true;
    imagePath.value = state.imagePath;
    selectedPresetIndex.value = state.selectedPresetIndex;
    filterIntensity.value = state.filterIntensity;
    blur.value = state.blur;
    vignette.value = state.vignette;
    brightness.value = state.brightness;
    contrast.value = state.contrast;
    exposure.value = state.exposure;
    vibrance.value = state.vibrance;
    temperature.value = state.temperature;
    selectedTemplateIndex.value = state.templateIndex;
    skewX.value = state.skewX;
    skewY.value = state.skewY;
    frameEnabled.value = state.frameEnabled;
    frameColor.value = state.frameColor;
    frameWidth.value = state.frameWidth;
    frameRadius.value = state.frameRadius;
    safeAreaEnabled.value = state.safeAreaEnabled;
    safeAreaPresetIndex.value = state.safeAreaPresetIndex;
    flipX.value = state.flipX;
    rotationQuarter.value = state.rotationQuarter;
    texts.assignAll(state.texts);
    stickers.assignAll(state.stickers);
    strokes.assignAll(state.strokes);
    activeTextId.value = null;
    activeStickerId.value = null;
    _restoring = false;
  }

  void _pushState({bool clearRedo = true, bool force = false}) {
    if (_restoring) return;
    final now = DateTime.now();
    if (!force &&
        _lastSnapshotAt != null &&
        now.difference(_lastSnapshotAt!) < _snapshotCooldown) {
      return;
    }
    _lastSnapshotAt = now;
    _undoStack.add(_snapshot());
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
    if (clearRedo) _redoStack.clear();
  }

  EditorState _snapshot() {
    return EditorState(
      imagePath: imagePath.value,
      selectedPresetIndex: selectedPresetIndex.value,
      filterIntensity: filterIntensity.value,
      blur: blur.value,
      vignette: vignette.value,
      brightness: brightness.value,
      contrast: contrast.value,
      exposure: exposure.value,
      vibrance: vibrance.value,
      temperature: temperature.value,
      templateIndex: selectedTemplateIndex.value,
      skewX: skewX.value,
      skewY: skewY.value,
      frameEnabled: frameEnabled.value,
      frameColor: frameColor.value,
      frameWidth: frameWidth.value,
      frameRadius: frameRadius.value,
      safeAreaEnabled: safeAreaEnabled.value,
      safeAreaPresetIndex: safeAreaPresetIndex.value,
      flipX: flipX.value,
      rotationQuarter: rotationQuarter.value,
      texts: texts.map((e) => e.copyWith()).toList(),
      stickers: stickers.map((e) => e.copyWith()).toList(),
      strokes: strokes.map((e) => e.copyWith(points: List.of(e.points))).toList(),
    );
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

List<double> _composeMatrix(List<double> a, List<double> b) {
  // Returns b * a (apply a, then b)
  final out = List<double>.filled(20, 0);
  for (var row = 0; row < 4; row++) {
    for (var col = 0; col < 4; col++) {
      var sum = 0.0;
      for (var k = 0; k < 4; k++) {
        sum += b[row * 5 + k] * a[k * 5 + col];
      }
      out[row * 5 + col] = sum;
    }
    out[row * 5 + 4] =
        b[row * 5 + 4] +
        (b[row * 5 + 0] * a[4] +
            b[row * 5 + 1] * a[9] +
            b[row * 5 + 2] * a[14] +
            b[row * 5 + 3] * a[19]);
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
    this.hidden = false,
    this.locked = false,
  });

  final int id;
  final String text;
  final Color color;
  final double fontSize;
  final double dx;
  final double dy;
  final bool hidden;
  final bool locked;

  EditorText copyWith({
    String? text,
    Color? color,
    double? fontSize,
    double? dx,
    double? dy,
    bool? hidden,
    bool? locked,
  }) {
    return EditorText(
      id: id,
      text: text ?? this.text,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      hidden: hidden ?? this.hidden,
      locked: locked ?? this.locked,
    );
  }
}

enum EditorStickerKind { emoji, rect, circle, arrow }
// Shape kinds reuse data as glyphs
extension EditorStickerKindShape on EditorStickerKind {
  static const shapeRect = EditorStickerKind.emoji;
  static const shapeCircle = EditorStickerKind.emoji;
  static const shapeArrow = EditorStickerKind.emoji;
}

enum ExportFormat { png, jpeg }

@immutable
class TemplateGuide {
  const TemplateGuide({required this.name, required this.aspectRatio});

  final String name;
  final double? aspectRatio;
}

@immutable
class EditorState {
  const EditorState({
    required this.imagePath,
    required this.selectedPresetIndex,
    required this.filterIntensity,
    required this.blur,
    required this.vignette,
    required this.brightness,
    required this.contrast,
    required this.exposure,
    required this.vibrance,
    required this.temperature,
    required this.templateIndex,
    required this.skewX,
    required this.skewY,
    required this.frameEnabled,
    required this.frameColor,
    required this.frameWidth,
    required this.frameRadius,
    required this.safeAreaEnabled,
    required this.safeAreaPresetIndex,
    required this.flipX,
    required this.rotationQuarter,
    required this.texts,
    required this.stickers,
    required this.strokes,
  });

  final String? imagePath;
  final int selectedPresetIndex;
  final double filterIntensity;
  final double blur;
  final double vignette;
  final double brightness;
  final double contrast;
  final double exposure;
  final double vibrance;
  final double temperature;
  final int templateIndex;
  final double skewX;
  final double skewY;
  final bool frameEnabled;
  final Color frameColor;
  final double frameWidth;
  final double frameRadius;
  final bool safeAreaEnabled;
  final int safeAreaPresetIndex;
  final bool flipX;
  final int rotationQuarter;
  final List<EditorText> texts;
  final List<EditorSticker> stickers;
  final List<EditorStroke> strokes;
}

@immutable
class SavedPreset {
  const SavedPreset({required this.name, required this.state});
  final String name;
  final EditorState state;
}

@immutable
class SafeAreaGuide {
  const SafeAreaGuide({
    required this.name,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });

  final String name;
  /// Fractions of width/height (0-1)
  final double left;
  final double right;
  final double top;
  final double bottom;
}

@immutable
class EditorSticker {
  const EditorSticker({
    required this.id,
    required this.kind,
    required this.data,
    required this.color,
    required this.dx,
    required this.dy,
    required this.scale,
    required this.rotation,
    required this.baseSize,
    this.hidden = false,
    this.locked = false,
  });

  final int id;
  final EditorStickerKind kind;
  final String data;
  final Color color;
  final double dx;
  final double dy;
  final double scale;
  final double rotation;
  final double baseSize;
  final bool hidden;
  final bool locked;

  EditorSticker copyWith({
    double? dx,
    double? dy,
    double? scale,
    double? rotation,
    Color? color,
    bool? hidden,
    bool? locked,
  }) {
    return EditorSticker(
      id: id,
      kind: kind,
      data: data,
      color: color ?? this.color,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      baseSize: baseSize,
      hidden: hidden ?? this.hidden,
      locked: locked ?? this.locked,
    );
  }
}

@immutable
class EditorStroke {
  const EditorStroke({
    required this.id,
    required this.points,
    required this.color,
    required this.width,
    required this.opacity,
  });

  final int id;
  final List<Offset> points;
  final Color color;
  final double width;
  final double opacity;

  EditorStroke copyWith({
    List<Offset>? points,
    Color? color,
    double? width,
    double? opacity,
  }) {
    return EditorStroke(
      id: id,
      points: points ?? this.points,
      color: color ?? this.color,
      width: width ?? this.width,
      opacity: opacity ?? this.opacity,
    );
  }
}
