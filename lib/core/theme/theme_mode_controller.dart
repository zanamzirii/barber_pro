import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeController extends ValueNotifier<ThemeMode> {
  ThemeModeController._() : super(ThemeMode.dark);

  static final ThemeModeController instance = ThemeModeController._();
  static const _prefKey = 'app_theme_mode';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      value = _fromString(raw);
    } on PlatformException {
      // Keep default mode if prefs channel is temporarily unavailable.
    } on MissingPluginException {
      // Can happen right after hot-restart while plugins re-register.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (value == mode) return;
    value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, _toString(mode));
    } on PlatformException {
      // Ignore persistence failure; runtime theme is already updated.
    } on MissingPluginException {
      // Ignore persistence failure; runtime theme is already updated.
    }
  }

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode _fromString(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }
}
