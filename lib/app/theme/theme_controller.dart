import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ThemeController extends GetxController {
  final _mode = ThemeMode.system.obs;

  ThemeMode get mode => _mode.value;

  void setMode(ThemeMode mode) {
    _mode.value = mode;
    update();
  }

  void toggleMode() {
    if (_mode.value == ThemeMode.dark) {
      setMode(ThemeMode.light);
    } else {
      setMode(ThemeMode.dark);
    }
  }
}
