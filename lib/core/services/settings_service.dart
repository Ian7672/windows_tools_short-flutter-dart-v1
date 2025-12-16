import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._prefs) : super(_readFromPrefs(_prefs));

  final SharedPreferences _prefs;

  static AppSettings _readFromPrefs(SharedPreferences prefs) {
    final modeIndex = prefs.getInt(_Keys.themeMode) ?? 0;
    final themeMode = ThemeMode.values.elementAt(
      modeIndex.clamp(0, ThemeMode.values.length - 1),
    );
    final defaults = AppSettings.defaults();
    return defaults.copyWith(
      themeMode: themeMode,
      localeCode:
          prefs.getString(_Keys.localeCode) ?? defaults.localeCode,
      showHighRiskTools:
          prefs.getBool(_Keys.showHighRiskTools) ?? defaults.showHighRiskTools,
      requireAdminConfirmation:
          prefs.getBool(_Keys.requireAdminConfirmation) ??
              defaults.requireAdminConfirmation,
      logRetentionDays:
          prefs.getInt(_Keys.logRetentionDays) ?? defaults.logRetentionDays,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setInt(_Keys.themeMode, mode.index);
  }

  Future<void> setLocaleCode(String code) async {
    state = state.copyWith(localeCode: code);
    await _prefs.setString(_Keys.localeCode, code);
  }

  Future<void> setShowHighRiskTools(bool value) async {
    state = state.copyWith(showHighRiskTools: value);
    await _prefs.setBool(_Keys.showHighRiskTools, value);
  }

  Future<void> setRequireAdminConfirmation(bool value) async {
    state = state.copyWith(requireAdminConfirmation: value);
    await _prefs.setBool(_Keys.requireAdminConfirmation, value);
  }

  Future<void> setLogRetentionDays(int days) async {
    state = state.copyWith(logRetentionDays: days);
    await _prefs.setInt(_Keys.logRetentionDays, days);
  }
}

class _Keys {
  static const themeMode = 'settings.themeMode';
  static const localeCode = 'settings.localeCode';
  static const showHighRiskTools = 'settings.showHighRisk';
  static const requireAdminConfirmation = 'settings.requireAdmin';
  static const logRetentionDays = 'settings.logRetentionDays';
}
