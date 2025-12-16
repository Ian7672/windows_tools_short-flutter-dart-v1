import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  AppPaths._({
    required this.root,
    required this.toolsRoot,
    required this.updaterToolsDir,
    required this.logsDir,
    required this.backupsDir,
    required this.disabledStartupDir,
  });

  final Directory root;
  final Directory toolsRoot;
  final Directory updaterToolsDir;
  final Directory logsDir;
  final Directory backupsDir;
  final Directory disabledStartupDir;

  Directory get junkReportsDir => Directory(p.join(logsDir.path, 'cleaner'));

  String manifestExtractionPath(String relative) =>
      p.join(toolsRoot.path, relative);

  static Future<AppPaths> initialize() async {
    final env = Platform.environment;
    final localAppData = env['LOCALAPPDATA'];
    final fallback = await getApplicationSupportDirectory();
    final rootDir = Directory(
      p.join(localAppData ?? fallback.path, 'Ian7672WindowsToolkit'),
    );
    final toolsDir = Directory(p.join(rootDir.path, 'tools'));
    final updaterDir = Directory(p.join(toolsDir.path, 'updater'));
    final logsDir = Directory(p.join(rootDir.path, 'logs'));
    final backupsDir = Directory(p.join(rootDir.path, 'backups'));
    final disabledStartupDir =
        Directory(p.join(rootDir.path, 'DisabledStartup'));

    for (final dir in [
      rootDir,
      toolsDir,
      updaterDir,
      logsDir,
      backupsDir,
      disabledStartupDir,
    ]) {
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    }

    final junkReportsDir = Directory(p.join(logsDir.path, 'cleaner'));
    if (!junkReportsDir.existsSync()) {
      junkReportsDir.createSync(recursive: true);
    }

    return AppPaths._(
      root: rootDir,
      toolsRoot: toolsDir,
      updaterToolsDir: updaterDir,
      logsDir: logsDir,
      backupsDir: backupsDir,
      disabledStartupDir: disabledStartupDir,
    );
  }
}
