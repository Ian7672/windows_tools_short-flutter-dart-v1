import 'dart:io';

import 'package:path/path.dart' as p;

class ExecutableCandidate {
  const ExecutableCandidate({required this.path, required this.displayName});

  final String path;
  final String displayName;
}

class ExecutableScanner {
  const ExecutableScanner({this.maxDepth = 3, this.maxResults = 120});

  final int maxDepth;
  final int maxResults;

  Future<List<ExecutableCandidate>> findUpdaterExecutables() async {
    final env = Platform.environment;
    final roots = <Directory>{
      if (env['ProgramFiles'] != null &&
          Directory(env['ProgramFiles']!).existsSync())
        Directory(env['ProgramFiles']!),
      if (env['ProgramFiles(x86)'] != null &&
          Directory(env['ProgramFiles(x86)']!).existsSync())
        Directory(env['ProgramFiles(x86)']!),
      if (env['ProgramData'] != null &&
          Directory(env['ProgramData']!).existsSync())
        Directory(env['ProgramData']!),
    }.toList();
    final results = <ExecutableCandidate>[];
    final seen = <String>{};
    for (final root in roots) {
      await _scanDirectory(root, results, seen, depth: 0);
      if (results.length >= maxResults) break;
    }
    return results;
  }

  Future<void> _scanDirectory(
    Directory dir,
    List<ExecutableCandidate> results,
    Set<String> seen, {
    required int depth,
  }) async {
    if (depth > maxDepth || results.length >= maxResults) return;
    try {
      final entries = dir.listSync(followLinks: false);
      for (final entity in entries) {
        if (results.length >= maxResults) break;
        if (entity is File) {
          final name = p.basename(entity.path).toLowerCase();
          if (!name.endsWith('.exe')) continue;
          if (!_isUpdaterName(name)) continue;
          final normalized = entity.path.toLowerCase();
          if (seen.add(normalized)) {
            results.add(
              ExecutableCandidate(
                path: entity.path,
                displayName: p.basename(entity.path),
              ),
            );
          }
        } else if (entity is Directory) {
          final baseName = p.basename(entity.path).toLowerCase();
          final shouldDescend =
              depth < maxDepth - 1 || _isUpdaterName(baseName);
          if (!shouldDescend) continue;
          await _scanDirectory(
            entity,
            results,
            seen,
            depth: depth + 1,
          );
        }
      }
    } catch (_) {
      // Ignore directories we can't read.
    }
  }

  bool _isUpdaterName(String name) {
    return name.contains('update') ||
        name.contains('updater') ||
        name.contains('upgrade');
  }
}
