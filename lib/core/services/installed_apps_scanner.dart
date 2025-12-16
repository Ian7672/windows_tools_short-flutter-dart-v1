import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:win32_registry/win32_registry.dart';

import 'executable_scanner.dart';

class InstalledApp {
  InstalledApp({
    required this.name,
    required this.installLocation,
    required this.executables,
  });

  final String name;
  final String installLocation;
  final List<ExecutableCandidate> executables;
}

class InstalledAppsScanner {
  const InstalledAppsScanner({this.maxExecutablesPerApp = 4});

  final int maxExecutablesPerApp;

  Future<List<InstalledApp>> scan() async {
    final results = <InstalledApp>[];
    for (final root in _registryRoots) {
      try {
        final handle = Registry.openPath(
          root.hive,
          path: root.path,
          desiredAccessRights: AccessRights.readOnly,
        );
        for (final subKeyName in handle.subkeyNames) {
          RegistryKey? sub;
          try {
            sub = Registry.openPath(
              root.hive,
              path: '${root.path}\\$subKeyName',
              desiredAccessRights: AccessRights.readOnly,
            );
          } catch (_) {
            continue;
          }
          final displayName = _readString(sub, 'DisplayName');
          if (displayName == null || displayName.isEmpty) {
            sub.close();
            continue;
          }
          final installLocation =
              _readString(sub, 'InstallLocation') ?? _parseDisplayIcon(sub);
          sub.close();
          if (installLocation == null ||
              installLocation.isEmpty ||
              !Directory(installLocation).existsSync()) {
            continue;
          }
          final executables = await _findUpdaterExecutables(installLocation);
          if (executables.isEmpty) continue;
          results.add(
            InstalledApp(
              name: displayName,
              installLocation: installLocation,
              executables: executables,
            ),
          );
        }
        handle.close();
      } catch (_) {
        continue;
      }
    }
    return results;
  }

  Future<List<ExecutableCandidate>> _findUpdaterExecutables(
    String directoryPath,
  ) async {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) return const [];
    final results = <ExecutableCandidate>[];
    final seen = <String>{};
    Future<void> scanDir(Directory current, int depth) async {
      if (depth > 1 || results.length >= maxExecutablesPerApp) return;
      try {
        final entries = current.listSync(followLinks: false);
        for (final entry in entries) {
          if (results.length >= maxExecutablesPerApp) break;
          if (entry is File && entry.path.toLowerCase().endsWith('.exe')) {
            final base = p.basename(entry.path).toLowerCase();
            if (!_looksLikeUpdater(base)) continue;
            final normalized = entry.path.toLowerCase();
            if (seen.add(normalized)) {
              results.add(
                ExecutableCandidate(
                  path: entry.path,
                  displayName: p.basename(entry.path),
                ),
              );
            }
          } else if (entry is Directory) {
            await scanDir(entry, depth + 1);
          }
        }
      } catch (_) {
        // ignore unreadable dirs
      }
    }

    await scanDir(dir, 0);
    return results;
  }

  bool _looksLikeUpdater(String name) {
    return name.contains('update') ||
        name.contains('updater') ||
        name.contains('upgrade');
  }

  String? _readString(RegistryKey key, String valueName) {
    try {
      final value = key.getValue(valueName);
      final data = value?.data;
      if (data is String) return data;
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _parseDisplayIcon(RegistryKey key) {
    final icon = _readString(key, 'DisplayIcon');
    if (icon == null || icon.isEmpty) return null;
    final path = icon.split(',').first.trim();
    if (path.isEmpty) return null;
    final file = File(path);
    if (file.existsSync()) {
      return p.dirname(file.path);
    }
    return null;
  }
}

class _RegistryRoot {
  const _RegistryRoot(this.hive, this.path);

  final RegistryHive hive;
  final String path;
}

const _registryRoots = <_RegistryRoot>[
  _RegistryRoot(
    RegistryHive.localMachine,
    r'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
  ),
  _RegistryRoot(
    RegistryHive.localMachine,
    r'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
  ),
  _RegistryRoot(
    RegistryHive.currentUser,
    r'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
  ),
];
