import 'package:flutter/material.dart';

class ThemeController {
  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  void toggle() {
    mode.value = mode.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  void set(ThemeMode m) => mode.value = m;
}

final themeController = ThemeController();
