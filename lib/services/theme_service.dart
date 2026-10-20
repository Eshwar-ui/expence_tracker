import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the app-wide appearance choice on this device.
class ThemeService extends ChangeNotifier {
  static final ThemeService instance = ThemeService();
  static const _preferenceKey = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_preferenceKey);
      _mode = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (error) {
      debugPrint('Unable to load appearance preference: $error');
      _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setDarkMode(bool enabled) async {
    final next = enabled ? ThemeMode.dark : ThemeMode.light;
    if (_mode == next) return;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_preferenceKey, next.name)) {
      throw StateError('Unable to save appearance preference');
    }
    _mode = next;
    notifyListeners();
  }

  Brightness resolveBrightness(Brightness systemBrightness) => switch (_mode) {
        ThemeMode.light => Brightness.light,
        ThemeMode.dark => Brightness.dark,
        ThemeMode.system => systemBrightness,
      };
}
