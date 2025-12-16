import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_languages.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final settingsController =
        ref.read(settingsControllerProvider.notifier);
    final paths = ref.watch(appPathsProvider);

    return ScaffoldPage(
      header: PageHeader(title: Text(t.pageSettingsTitle)),
      content: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.settingsAppearanceTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ComboBox<ThemeMode>(
                    value: settings.themeMode,
                    items: ThemeMode.values
                        .map(
                          (mode) => ComboBoxItem(
                            value: mode,
                            child: Text(mode.name),
                          ),
                        )
                        .toList(),
                    onChanged: (mode) {
                      if (mode != null) {
                        settingsController.setThemeMode(mode);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: t.settingsLanguage,
                    child: ComboBox<String>(
                      value: settings.localeCode,
                      items: kSupportedLanguages
                          .map(
                            (lang) => ComboBoxItem<String>(
                              value: lang.code,
                              child: Text(lang.label),
                            ),
                          )
                          .toList(),
                      onChanged: (code) {
                        if (code != null) {
                          settingsController.setLocaleCode(code);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.settingsToolVisibilityTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ToggleSwitch(
                    checked: settings.showHighRiskTools,
                    content: Text(t.settingsShowHighRisk),
                    onChanged: settingsController.setShowHighRiskTools,
                  ),
                  const SizedBox(height: 4),
                  ToggleSwitch(
                    checked: settings.requireAdminConfirmation,
                    content: Text(t.settingsRequireAdmin),
                    onChanged: settingsController.setRequireAdminConfirmation,
                  ),
                ],
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.settingsLogsTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InfoLabel(
                    label: t.settingsLogRetention,
                    child: NumberBox(
                      value: settings.logRetentionDays,
                      min: 1,
                      max: 60,
                      onChanged: (value) {
                        if (value != null) {
                          settingsController.setLogRetentionDays(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Button(
                        onPressed: () {
                          _openFolder(paths.toolsRoot.path);
                        },
                        child: Text(t.settingsOpenTools),
                      ),
                      Button(
                        onPressed: () {
                          _openFolder(paths.backupsDir.path);
                        },
                        child: Text(t.settingsOpenBackups),
                      ),
                      Button(
                        onPressed: () {
                          _openFolder(paths.logsDir.path);
                        },
                        child: Text(t.settingsOpenLogs),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${t.settingsAppDataRoot}: ${paths.root.path}'),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

void _openFolder(String path) {
  final target = path.replaceAll('"', '""');
  Process.start(
    'cmd.exe',
    ['/c', 'start', '', '"$target"'],
    runInShell: true,
  );
}
