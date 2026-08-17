import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.dark) {
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
      case ThemeMode.dark:
        setTheme(ThemeMode.light);
        break;
      case ThemeMode.light:
        setTheme(ThemeMode.system);
        break;
      case ThemeMode.system:
        setTheme(ThemeMode.dark);
        break;
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>(
  (ref) => ThemeNotifier(),
);
