import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  // Start on `system` so the very first frame already matches the device;
  // the stored preference is applied as soon as it loads.
  ThemeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    state = await StorageService.getThemeMode();
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    await StorageService.setThemeMode(mode);
  }

  void toggleTheme() {
    switch (state) {
      case ThemeMode.system:
        setTheme(ThemeMode.light);
        break;
      case ThemeMode.light:
        setTheme(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        setTheme(ThemeMode.system);
        break;
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>(
  (ref) => ThemeNotifier(),
);
