import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.localeCode,
    required this.showHighRiskTools,
    required this.requireAdminConfirmation,
    required this.logRetentionDays,
  });

  final ThemeMode themeMode;
  final String localeCode;
  final bool showHighRiskTools;
  final bool requireAdminConfirmation;
  final int logRetentionDays;

  factory AppSettings.defaults() => const AppSettings(
        themeMode: ThemeMode.system,
        localeCode: 'en',
        showHighRiskTools: true,
        requireAdminConfirmation: true,
        logRetentionDays: 14,
      );

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? localeCode,
    bool? showHighRiskTools,
    bool? requireAdminConfirmation,
    int? logRetentionDays,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      localeCode: localeCode ?? this.localeCode,
      showHighRiskTools: showHighRiskTools ?? this.showHighRiskTools,
      requireAdminConfirmation:
          requireAdminConfirmation ?? this.requireAdminConfirmation,
      logRetentionDays: logRetentionDays ?? this.logRetentionDays,
    );
  }
}
