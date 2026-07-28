import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const _key = 'dark_mode';
  static final ValueNotifier<bool> isDark = ValueNotifier(false);

  static Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_key) ?? false;
    isDark.value = value;
    return value;
  }

  static Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    isDark.value = value;
  }

  static Future<void> toggleDarkMode() async {
    await setDarkMode(!isDark.value);
  }
}
