import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localePrefKey = 'app_locale_code';

final appLocaleProvider =
    StateNotifierProvider<AppLocaleNotifier, Locale?>((ref) {
  return AppLocaleNotifier()..load();
});

class AppLocaleNotifier extends StateNotifier<Locale?> {
  AppLocaleNotifier() : super(null);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_localePrefKey);
    if (languageCode == null || languageCode.isEmpty) {
      state = null;
      return;
    }
    state = Locale(languageCode);
  }

  Future<void> setLocale(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localePrefKey, languageCode);
    state = Locale(languageCode);
  }

  Future<void> clearLocale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localePrefKey);
    state = null;
  }
}
