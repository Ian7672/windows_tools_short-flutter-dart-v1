import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart' as win32;
import 'package:win32_registry/win32_registry.dart';

import '../models/browser_entry.dart';
import '../models/junk_entries.dart';

const _categoryTempUser = 'temp_user';
const _categoryTempWindows = 'temp_windows';
const _categoryRecycle = 'recycle_bin';
const _categoryWindowsUpdate = 'cleanWindowsUpdate';
const _categoryTempInstall = 'cleanTemporaryInstall';
const _categoryDriverPackages = 'cleanDriverPackages';
const _categoryPreviousWindows = 'cleanPreviousInstalls';
const _categoryDisableHibernation = 'disableHibernation';
const _categoryComponentCleanup = 'componentCleanup';
const _categoryBrowserPrefix = 'browser_';

const _windowsUpdateCleanupPaths = [
  r'%WINDIR%\SoftwareDistribution\Download',
  r'%WINDIR%\SoftwareDistribution\DataStore\Logs',
  r'%WINDIR%\SoftwareDistribution\DeliveryOptimization\Cache',
  r'%WINDIR%\SoftwareDistribution\PostRebootEventCache',
];

const _temporaryInstallPaths = [
  r'%SYSTEMDRIVE%\$WINDOWS.~BT',
  r'%SYSTEMDRIVE%\$WINDOWS.~WS',
  r'%WINDIR%\Panther',
  r'%WINDIR%\SoftwareDistribution\SelfUpdate',
  r'%WINDIR%\Setup\Scripts',
];

const _componentCleanupPaths = [
  r'%WINDIR%\WinSxS\Temp',
  r'%WINDIR%\WinSxS\ManifestCache',
  r'%WINDIR%\servicing\LCU',
  r'%WINDIR%\Logs\CBS',
];

const _hibernationPaths = [
  r'%SYSTEMDRIVE%\hiberfil.sys',
];

enum _BrowserKind { chromium, firefox, opera }

enum _EnvScope { localAppData, appData }

class _EnvPath {
  const _EnvPath(this.scope, this.relativePath);

  final _EnvScope scope;
  final String relativePath;
}

class _BrowserDefinition {
  const _BrowserDefinition({
    required this.id,
    required this.label,
    required this.kind,
    this.userDataDirs = const <_EnvPath>[],
    this.cacheBaseDirs = const <_EnvPath>[],
    this.exeRegistryKeys = const <String>[],
    this.exeFallbacks = const <String>[],
  });

  final String id;
  final String label;
  final _BrowserKind kind;
  final List<_EnvPath> userDataDirs;
  final List<_EnvPath> cacheBaseDirs;
  final List<String> exeRegistryKeys;
  final List<String> exeFallbacks;
}

class _BrowserProfile {
  const _BrowserProfile({
    required this.profilePath,
    required this.cacheRoots,
  });

  final String profilePath;
  final List<String> cacheRoots;
}

class _FirefoxProfileInfo {
  const _FirefoxProfileInfo({
    required this.path,
    required this.isRelative,
  });

  final String path;
  final bool isRelative;
}

const _chromiumCacheSubdirs = <String>[
  'Cache',
  'Code Cache',
  'GPUCache',
  'ShaderCache',
  'GrShaderCache',
  'Service Worker\\CacheStorage',
  'Media Cache',
];

const _operaCacheSubdirs = <String>[
  'Cache',
  'Code Cache',
  'GPUCache',
  'ShaderCache',
  'Service Worker\\CacheStorage',
  'Media Cache',
];

const _browserDefinitions = <_BrowserDefinition>[
  _BrowserDefinition(
    id: 'chrome',
    label: 'Chrome',
    kind: _BrowserKind.chromium,
    userDataDirs: [
      _EnvPath(_EnvScope.localAppData, r'Google\Chrome\User Data'),
    ],
    exeRegistryKeys: [
      r'SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe',
    ],
    exeFallbacks: [
      r'%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe',
      r'%PROGRAMFILES%\Google\Chrome\Application\chrome.exe',
      r'%PROGRAMFILES(X86)%\Google\Chrome\Application\chrome.exe',
    ],
  ),
  _BrowserDefinition(
    id: 'edge',
    label: 'Edge',
    kind: _BrowserKind.chromium,
    userDataDirs: [
      _EnvPath(_EnvScope.localAppData, r'Microsoft\Edge\User Data'),
    ],
    exeRegistryKeys: [
      r'SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe',
    ],
    exeFallbacks: [
      r'%LOCALAPPDATA%\Microsoft\Edge\Application\msedge.exe',
      r'%PROGRAMFILES%\Microsoft\Edge\Application\msedge.exe',
      r'%PROGRAMFILES(X86)%\Microsoft\Edge\Application\msedge.exe',
    ],
  ),
  _BrowserDefinition(
    id: 'brave',
    label: 'Brave',
    kind: _BrowserKind.chromium,
    userDataDirs: [
      _EnvPath(
        _EnvScope.localAppData,
        r'BraveSoftware\Brave-Browser\User Data',
      ),
    ],
    exeRegistryKeys: [
      r'SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\brave.exe',
    ],
    exeFallbacks: [
      r'%LOCALAPPDATA%\BraveSoftware\Brave-Browser\Application\brave.exe',
      r'%PROGRAMFILES%\BraveSoftware\Brave-Browser\Application\brave.exe',
      r'%PROGRAMFILES(X86)%\BraveSoftware\Brave-Browser\Application\brave.exe',
    ],
  ),
  _BrowserDefinition(
    id: 'vivaldi',
    label: 'Vivaldi',
    kind: _BrowserKind.chromium,
    userDataDirs: [
      _EnvPath(_EnvScope.localAppData, r'Vivaldi\User Data'),
    ],
    exeFallbacks: [
      r'%LOCALAPPDATA%\Vivaldi\Application\vivaldi.exe',
      r'%PROGRAMFILES%\Vivaldi\Application\vivaldi.exe',
      r'%PROGRAMFILES(X86)%\Vivaldi\Application\vivaldi.exe',
    ],
  ),
  _BrowserDefinition(
    id: 'yandex',
    label: 'Yandex',
    kind: _BrowserKind.chromium,
    userDataDirs: [
      _EnvPath(_EnvScope.localAppData, r'Yandex\YandexBrowser\User Data'),
    ],
    exeFallbacks: [
      r'%LOCALAPPDATA%\Yandex\YandexBrowser\Application\browser.exe',
      r'%PROGRAMFILES%\Yandex\YandexBrowser\Application\browser.exe',
      r'%PROGRAMFILES(X86)%\Yandex\YandexBrowser\Application\browser.exe',
    ],
  ),
  _BrowserDefinition(
    id: 'opera',
    label: 'Opera',
    kind: _BrowserKind.opera,
    userDataDirs: [
      _EnvPath(_EnvScope.appData, r'Opera Software\Opera Stable'),
    ],
    cacheBaseDirs: [
      _EnvPath(_EnvScope.localAppData, r'Opera Software\Opera Stable'),
    ],
    exeFallbacks: [
      r'%LOCALAPPDATA%\Programs\Opera\launcher.exe',
      r'%PROGRAMFILES%\Opera\launcher.exe',
      r'%PROGRAMFILES(X86)%\Opera\launcher.exe',
    ],
  ),
  _BrowserDefinition(
    id: 'operaGX',
    label: 'Opera GX',
    kind: _BrowserKind.opera,
    userDataDirs: [
      _EnvPath(_EnvScope.appData, r'Opera Software\Opera GX Stable'),
    ],
    cacheBaseDirs: [
      _EnvPath(_EnvScope.localAppData, r'Opera Software\Opera GX Stable'),
    ],
    exeFallbacks: [
      r'%LOCALAPPDATA%\Programs\Opera GX\launcher.exe',
      r'%PROGRAMFILES%\Opera GX\launcher.exe',
      r'%PROGRAMFILES(X86)%\Opera GX\launcher.exe',
    ],
  ),
  _BrowserDefinition(
    id: 'firefox',
    label: 'Firefox',
    kind: _BrowserKind.firefox,
    exeRegistryKeys: [
      r'SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\firefox.exe',
    ],
    exeFallbacks: [
      r'%PROGRAMFILES%\Mozilla Firefox\firefox.exe',
      r'%PROGRAMFILES(X86)%\Mozilla Firefox\firefox.exe',
    ],
  ),
];

final _browserDefinitionMap = {
  for (final def in _browserDefinitions) def.id: def,
};

typedef ScanProgressCallback = void Function(String path);

class _ScanStats {
  _ScanStats({
    required this.sizeBytes,
    required this.fileCount,
    List<String>? errors,
  }) : errors = errors ?? <String>[];

  final int sizeBytes;
  final int fileCount;
  final List<String> errors;
}

class JunkCleanerService {
  const JunkCleanerService();

  String get _windowsDir => Platform.environment['WINDIR'] ?? r'C:\Windows';
  String get _systemDrive => Platform.environment['SystemDrive'] ?? 'C:';

  String get recycleBinPath =>
      p.join(_systemDrive, r'\$Recycle.Bin');

  Future<JunkScanResult> scan({
    bool includeRecycleBin = false,
    ScanProgressCallback? onProgress,
  }) async {
    final entries = <JunkEntry>[];
    final categories = <String, JunkCategoryInfo>{};

    final userTemp = await _scanEntry(
      label: 'User Temp',
      path: Directory.systemTemp.path,
      onProgress: onProgress,
    );
    entries.add(userTemp);
    categories[_categoryTempUser] = _categoryFromEntry(
      id: _categoryTempUser,
      label: 'User Temp',
      entry: userTemp,
    );

    final systemTemp = await _scanEntry(
      label: 'Windows Temp',
      path: p.join(_windowsDir, 'Temp'),
      onProgress: onProgress,
    );
    entries.add(systemTemp);
    categories[_categoryTempWindows] = _categoryFromEntry(
      id: _categoryTempWindows,
      label: 'Windows Temp',
      entry: systemTemp,
    );

    final recycleCategory = await _scanCategoryPaths(
      id: _categoryRecycle,
      label: 'Recycle Bin',
      paths: [recycleBinPath],
      onProgress: onProgress,
    );
    categories[_categoryRecycle] = recycleCategory;
    if (includeRecycleBin) {
      entries.add(
        JunkEntry(
          path: recycleBinPath,
          label: recycleCategory.label,
          sizeBytes: recycleCategory.sizeBytes,
          fileCount: recycleCategory.fileCount,
          errors: recycleCategory.errors,
        ),
      );
    }

    categories[_categoryWindowsUpdate] = await _scanCategoryPaths(
      id: _categoryWindowsUpdate,
      label: 'Windows Update Cleanup',
      paths: _windowsUpdateCleanupPaths,
      onProgress: onProgress,
    );
    categories[_categoryTempInstall] = await _scanCategoryPaths(
      id: _categoryTempInstall,
      label: 'Temporary installation files',
      paths: _temporaryInstallPaths,
      onProgress: onProgress,
    );
    categories[_categoryDisableHibernation] = await _scanCategoryPaths(
      id: _categoryDisableHibernation,
      label: 'Hibernation file',
      paths: _hibernationPaths,
      onProgress: onProgress,
    );
    categories[_categoryComponentCleanup] = await _scanCategoryPaths(
      id: _categoryComponentCleanup,
      label: 'Component store cleanup',
      paths: _componentCleanupPaths,
      onProgress: onProgress,
    );
    categories[_categoryDriverPackages] =
        await _scanDriverPackagesCategory(onProgress: onProgress);
    categories[_categoryPreviousWindows] =
        await _scanPreviousInstallationsCategory(onProgress: onProgress);

    final browserCategories = await _scanBrowserCategories(onProgress);
    categories.addAll(browserCategories);

    return JunkScanResult(
      entries: entries,
      scannedAt: DateTime.now(),
      categories: categories,
    );
  }

  Future<JunkEntry> _scanEntry({
    required String label,
    required String path,
    ScanProgressCallback? onProgress,
  }) async {
    final resolved = _expandEnvTokens(path);
    onProgress?.call(resolved);
    final stats = await _scanPath(resolved, onProgress: onProgress);
    return JunkEntry(
      path: resolved,
      label: label,
      sizeBytes: stats.sizeBytes,
      fileCount: stats.fileCount,
      errors: stats.errors,
    );
  }

  JunkCategoryInfo _categoryFromEntry({
    required String id,
    required String label,
    required JunkEntry entry,
  }) {
    return JunkCategoryInfo(
      id: id,
      label: label,
      sizeBytes: entry.sizeBytes,
      fileCount: entry.fileCount,
      paths: [entry.path],
      errors: entry.errors,
    );
  }

  Future<JunkCategoryInfo> _scanCategoryPaths({
    required String id,
    required String label,
    required List<String> paths,
    ScanProgressCallback? onProgress,
  }) async {
    var totalSize = 0;
    var totalFiles = 0;
    final errors = <String>[];
    final resolved = <String>[];
    for (final raw in paths) {
      final target = _expandEnvTokens(raw);
      resolved.add(target);
      final stats = await _scanPath(target, onProgress: onProgress);
      totalSize += stats.sizeBytes;
      totalFiles += stats.fileCount;
      errors.addAll(stats.errors);
    }
    return JunkCategoryInfo(
      id: id,
      label: label,
      sizeBytes: totalSize,
      fileCount: totalFiles,
      paths: resolved,
      errors: errors,
    );
  }

  Future<JunkCategoryInfo> _scanDriverPackagesCategory({
    ScanProgressCallback? onProgress,
  }) async {
    final repoPath =
        p.join(_windowsDir, 'System32', 'DriverStore', 'FileRepository');
    final repo = Directory(repoPath);
    if (!await repo.exists()) {
      return JunkCategoryInfo(
        id: _categoryDriverPackages,
        label: 'Driver packages (temporary)',
        sizeBytes: 0,
        fileCount: 0,
        paths: [repoPath],
      );
    }
    var totalSize = 0;
    var totalFiles = 0;
    final errors = <String>[];
    await for (final entity in repo.list(followLinks: false)) {
      final name = p.basename(entity.path).toLowerCase();
      if (entity is Directory) {
        final looksTemporary = name.contains('tmp') || name.contains('temp');
        if (!looksTemporary) continue;
        final stats = await _scanPath(
          entity.path,
          onProgress: onProgress,
        );
        totalSize += stats.sizeBytes;
        totalFiles += stats.fileCount;
        errors.addAll(stats.errors);
      } else if (entity is File) {
        if (name.endsWith('.log') || name.endsWith('.tmp')) {
          final stats = await _scanPath(
            entity.path,
            onProgress: onProgress,
          );
          totalSize += stats.sizeBytes;
          totalFiles += stats.fileCount;
          errors.addAll(stats.errors);
        }
      }
    }
    return JunkCategoryInfo(
      id: _categoryDriverPackages,
      label: 'Driver packages (temporary)',
      sizeBytes: totalSize,
      fileCount: totalFiles,
      paths: [repoPath],
      errors: errors,
    );
  }

  Future<JunkCategoryInfo> _scanPreviousInstallationsCategory({
    ScanProgressCallback? onProgress,
  }) async {
    final root = Directory('$_systemDrive\\');
    if (!await root.exists()) {
      return JunkCategoryInfo(
        id: _categoryPreviousWindows,
        label: 'Previous Windows installations',
        sizeBytes: 0,
        fileCount: 0,
        paths: const [],
      );
    }
    var totalSize = 0;
    var totalFiles = 0;
    final errors = <String>[];
    final paths = <String>[];
    await for (final entity in root.list(followLinks: false)) {
      final name = p.basename(entity.path).toLowerCase();
      if (!name.startsWith('windows.old')) continue;
      final stats = await _scanPath(
        entity.path,
        onProgress: onProgress,
      );
      totalSize += stats.sizeBytes;
      totalFiles += stats.fileCount;
      errors.addAll(stats.errors);
      paths.add(entity.path);
    }
    return JunkCategoryInfo(
      id: _categoryPreviousWindows,
      label: 'Previous Windows installations',
      sizeBytes: totalSize,
      fileCount: totalFiles,
      paths: paths,
      errors: errors,
    );
  }

  Future<Map<String, JunkCategoryInfo>> _scanBrowserCategories(
    ScanProgressCallback? onProgress,
  ) async {
    final map = <String, JunkCategoryInfo>{};
    for (final definition in _browserDefinitions) {
      final info = await _scanBrowserCategory(definition, onProgress);
      if (info != null) {
        map[info.id] = info;
      }
    }
    return map;
  }

  Future<JunkCategoryInfo?> _scanBrowserCategory(
    _BrowserDefinition definition,
    ScanProgressCallback? onProgress,
  ) async {
    final profiles = await _findBrowserProfiles(definition);
    if (profiles.isEmpty) return null;
    var totalSize = 0;
    var totalFiles = 0;
    final errors = <String>[];
    final paths = <String>[];
    for (final profile in profiles) {
      for (final cacheRoot in profile.cacheRoots) {
        final stats = await _scanPath(
          cacheRoot,
          onProgress: onProgress,
        );
        totalSize += stats.sizeBytes;
        totalFiles += stats.fileCount;
        errors.addAll(stats.errors);
        paths.add(cacheRoot);
      }
    }
    return JunkCategoryInfo(
      id: '$_categoryBrowserPrefix${definition.id}',
      label: '${definition.label} cache',
      sizeBytes: totalSize,
      fileCount: totalFiles,
      paths: paths,
      errors: errors,
    );
  }

  Future<_ScanStats> _scanPath(
    String path, {
    ScanProgressCallback? onProgress,
  }) async {
    onProgress?.call(path);
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      return _ScanStats(sizeBytes: 0, fileCount: 0);
    }
    var size = 0;
    var count = 0;
    final errors = <String>[];
    if (type == FileSystemEntityType.directory) {
      final directory = Directory(path);
      try {
        await for (final entity
            in directory.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            count++;
            try {
              size += await entity.length();
            } catch (err) {
              errors.add('${entity.path}: $err');
            }
          }
        }
      } catch (err) {
        errors.add('$path: $err');
      }
    } else if (type == FileSystemEntityType.file) {
      try {
        size += await File(path).length();
        count = 1;
      } catch (err) {
        errors.add('$path: $err');
      }
    }
    return _ScanStats(sizeBytes: size, fileCount: count, errors: errors);
  }

  Future<JunkScanResult> clean(
    JunkScanResult scanResult, {
    bool includeRecycleBin = false,
  }) async {
    final targets = scanResult.entries.where((entry) {
      if (entry.path == recycleBinPath) {
        return includeRecycleBin;
      }
      return true;
    });
    for (final entry in targets) {
      await _deleteContents(entry.path);
    }
    return scanResult;
  }

  Future<void> cleanWindowsUpdateData() async {
    final paths = [
      p.join(_windowsDir, 'SoftwareDistribution', 'Download'),
      p.join(_windowsDir, 'SoftwareDistribution', 'DataStore', 'Logs'),
      p.join(_windowsDir, 'SoftwareDistribution', 'DeliveryOptimization', 'Cache'),
      p.join(_windowsDir, 'SoftwareDistribution', 'PostRebootEventCache')
    ];
    for (final path in paths) {
      await _deleteContents(path);
    }
  }

  Future<void> cleanTemporaryInstallFiles() async {
    final systemRoot = _systemDrive;
    final targets = [
      p.join(systemRoot, r'\$WINDOWS.~BT'),
      p.join(systemRoot, r'\$WINDOWS.~WS'),
      p.join(_windowsDir, 'Panther'),
      p.join(_windowsDir, 'SoftwareDistribution', 'SelfUpdate'),
      p.join(_windowsDir, 'Setup', 'Scripts'),
    ];
    for (final path in targets) {
      await _deletePath(path);
    }
  }

  Future<void> cleanDriverPackages() async {
    final repo = Directory(p.join(_windowsDir, 'System32', 'DriverStore', 'FileRepository'));
    if (!await repo.exists()) return;
    await for (final entity in repo.list(followLinks: false)) {
      if (entity is Directory) {
        final name = p.basename(entity.path).toLowerCase();
        final looksTemporary = name.contains('tmp') || name.contains('temp');
        if (looksTemporary) {
          await _deletePath(entity.path);
        }
      } else if (entity is File) {
        final name = p.basename(entity.path).toLowerCase();
        if (name.endsWith('.log') || name.endsWith('.tmp')) {
          await _deletePath(entity.path);
        }
      }
    }
  }

  Future<void> cleanPreviousInstallations() async {
    final root = Directory('$_systemDrive\\');
    if (!await root.exists()) return;
    await for (final entity in root.list(followLinks: false)) {
      final name = p.basename(entity.path).toLowerCase();
      if (name.startsWith('windows.old')) {
        await _deletePath(entity.path);
      }
    }
  }

  Future<void> cleanupComponentStore() async {
    final targets = [
      p.join(_windowsDir, 'WinSxS', 'Temp'),
      p.join(_windowsDir, 'WinSxS', 'ManifestCache'),
      p.join(_windowsDir, 'servicing', 'LCU'),
      p.join(_windowsDir, 'Logs', 'CBS'),
    ];
    for (final path in targets) {
      await _deleteContents(path);
    }
  }

  Future<void> cleanBrowserCaches(Set<String> browserIds) async {
    for (final id in browserIds) {
      final definition = _browserDefinitionMap[id];
      if (definition == null) continue;
      final profiles = await _findBrowserProfiles(definition);
      for (final profile in profiles) {
        for (final cache in profile.cacheRoots) {
          await _deleteContents(cache);
        }
      }
    }
  }

  Future<List<BrowserEntry>> detectBrowserData() async {
    final entries = <BrowserEntry>[];
    for (final definition in _browserDefinitions) {
      final profiles = await _findBrowserProfiles(definition);
      if (profiles.isEmpty) continue;
      final executable = _resolveExecutable(definition);
      entries.add(
        BrowserEntry(
          id: definition.id,
          label: definition.label,
          profileCount: profiles.length,
          executablePath: executable,
        ),
      );
    }
    return entries;
  }

  Future<void> disableHibernation() async {
    await _setHibernateRegistry(0);
    await _reserveHiberFile(false);
  }

  Future<void> enableHibernation() async {
    await _setHibernateRegistry(1);
    await _reserveHiberFile(true);
  }

  Future<void> _setHibernateRegistry(int value) async {
    final key = Registry.openPath(
      RegistryHive.localMachine,
      path: r'SYSTEM\CurrentControlSet\Control\Power',
      desiredAccessRights: AccessRights.allAccess,
    );
    try {
      key.createValue(
        RegistryValue(
          'HibernateEnabled',
          RegistryValueType.int32,
          value,
        ),
      );
      key.createValue(
        RegistryValue(
          'HibernateEnabledDefault',
          RegistryValueType.int32,
          value,
        ),
      );
    } finally {
      key.close();
    }
  }

  Future<void> _reserveHiberFile(bool enable) async {
    final input = calloc<Uint32>()..value = enable ? 1 : 0;
    try {
      final status = win32.CallNtPowerInformation(
        win32.SystemReserveHiberFile,
        input.cast(),
        sizeOf<Uint32>(),
        nullptr,
        0,
      );
      if (status != win32.STATUS_SUCCESS) {
        throw Exception(
          'CallNtPowerInformation failed with status 0x${status.toRadixString(16)}',
        );
      }
    } finally {
      calloc.free(input);
    }
  }

  Future<void> _deleteContents(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      await _deleteEntity(entity);
    }
  }

  Future<void> _deletePath(String path) async {
    try {
      final entityType = FileSystemEntity.typeSync(path);
      if (entityType == FileSystemEntityType.notFound) return;
      if (entityType == FileSystemEntityType.directory) {
        await Directory(path).delete(recursive: true);
      } else {
        await File(path).delete();
      }
    } catch (_) {
      // ignore protected paths
    }
  }

  Future<void> _deleteEntity(FileSystemEntity entity) async {
    try {
      if (entity is Directory) {
        await entity.delete(recursive: true);
      } else {
        await entity.delete();
      }
    } catch (_) {
      // ignore protected files
    }
  }

  Future<List<_BrowserProfile>> _findBrowserProfiles(
    _BrowserDefinition definition,
  ) {
    switch (definition.kind) {
      case _BrowserKind.chromium:
        return _findChromiumProfiles(definition);
      case _BrowserKind.firefox:
        return _findFirefoxProfiles();
      case _BrowserKind.opera:
        return _findOperaProfiles(definition);
    }
  }

  Future<List<_BrowserProfile>> _findChromiumProfiles(
    _BrowserDefinition definition,
  ) async {
    final profiles = <_BrowserProfile>[];
    for (final envPath in definition.userDataDirs) {
      final base = _resolveEnvPath(envPath);
      final dir = Directory(base);
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final name = p.basename(entity.path);
        if (!_looksLikeChromiumProfile(name)) continue;
        final cacheRoots = _chromiumCacheSubdirs
            .map((sub) => p.join(entity.path, sub))
            .toList();
        profiles.add(
          _BrowserProfile(
            profilePath: entity.path,
            cacheRoots: cacheRoots,
          ),
        );
      }
    }
    return profiles;
  }

  Future<List<_BrowserProfile>> _findOperaProfiles(
    _BrowserDefinition definition,
  ) async {
    final profiles = <_BrowserProfile>[];
    final cacheBaseMap = {
      for (final envPath in definition.cacheBaseDirs)
        envPath.relativePath.toLowerCase(): _resolveEnvPath(envPath),
    };
    for (final envPath in definition.userDataDirs) {
      final profilePath = _resolveEnvPath(envPath);
      if (!await Directory(profilePath).exists()) continue;
      final cacheBase = cacheBaseMap[envPath.relativePath.toLowerCase()];
      final cacheRoots = <String>[];
      if (cacheBase != null) {
        cacheRoots.addAll(
          _operaCacheSubdirs.map((sub) => p.join(cacheBase, sub)),
        );
      }
      cacheRoots.add(
        p.join(profilePath, 'Service Worker', 'CacheStorage'),
      );
      profiles.add(
        _BrowserProfile(
          profilePath: profilePath,
          cacheRoots: cacheRoots,
        ),
      );
    }
    return profiles;
  }

  Future<List<_BrowserProfile>> _findFirefoxProfiles() async {
    final iniFile = File(
      p.join(_appData, 'Mozilla', 'Firefox', 'profiles.ini'),
    );
    if (!await iniFile.exists()) {
      return const <_BrowserProfile>[];
    }
    List<String> lines;
    try {
      lines = await iniFile.readAsLines(encoding: latin1);
    } on FormatException {
      lines = await iniFile.readAsLines();
    }
    final infos = _parseFirefoxProfilesIni(lines);
    final profiles = <_BrowserProfile>[];
    for (final info in infos) {
      final profilePath = info.isRelative
          ? p.join(_appData, 'Mozilla', 'Firefox', info.path)
          : info.path;
      if (!await Directory(profilePath).exists()) continue;
      final localCache = p.join(
        _localAppData,
        'Mozilla',
        'Firefox',
        'Profiles',
        p.basename(profilePath),
        'cache2',
      );
      final cacheRoots = <String>[
        localCache,
        p.join(profilePath, 'cache2'),
        p.join(profilePath, 'startupCache'),
      ];
      profiles.add(
        _BrowserProfile(
          profilePath: profilePath,
          cacheRoots: cacheRoots,
        ),
      );
    }
    return profiles;
  }

  List<_FirefoxProfileInfo> _parseFirefoxProfilesIni(List<String> lines) {
    final result = <_FirefoxProfileInfo>[];
    var current = <String, String>{};
    var section = '';

    void flush() {
      if (section.toLowerCase().startsWith('profile')) {
        final path = current['Path'];
        if (path != null) {
          final isRelative = current['IsRelative'] == '1';
          result.add(
            _FirefoxProfileInfo(
              path: path.replaceAll('/', Platform.pathSeparator),
              isRelative: isRelative,
            ),
          );
        }
      }
      current = <String, String>{};
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith(';')) continue;
      if (line.startsWith('[') && line.endsWith(']')) {
        flush();
        section = line.substring(1, line.length - 1);
      } else {
        final idx = line.indexOf('=');
        if (idx == -1) continue;
        final key = line.substring(0, idx);
        final value = line.substring(idx + 1);
        current[key] = value;
      }
    }
    flush();
    return result;
  }

  bool _looksLikeChromiumProfile(String name) {
    if (name == 'Default' ||
        name == 'System Profile' ||
        name == 'Guest Profile') {
      return true;
    }
    return name.startsWith('Profile ');
  }

  String _resolveEnvPath(_EnvPath path) =>
      p.join(_envBase(path.scope), path.relativePath);

  String _envBase(_EnvScope scope) =>
      scope == _EnvScope.localAppData ? _localAppData : _appData;

  String? _resolveExecutable(_BrowserDefinition definition) {
    for (final key in definition.exeRegistryKeys) {
      final registryValue = _readRegistryString(key);
      if (registryValue != null && registryValue.isNotEmpty) {
        return registryValue;
      }
    }
    for (final fallback in definition.exeFallbacks) {
      final expanded = _expandEnvTokens(fallback);
      if (expanded.isEmpty) continue;
      if (File(expanded).existsSync()) {
        return expanded;
      }
    }
    return null;
  }

  String? _readRegistryString(String keyPath) {
    for (final hive in [
      RegistryHive.localMachine,
      RegistryHive.currentUser,
    ]) {
      try {
        final key = Registry.openPath(
          hive,
          path: keyPath,
          desiredAccessRights: AccessRights.readOnly,
        );
        final value = key.getValue('');
        key.close();
        if (value != null && value.data is String) {
          return value.data as String;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  String _expandEnvTokens(String input) {
    if (!input.contains('%')) {
      return input;
    }
    final env = Platform.environment;
    return input.replaceAllMapped(RegExp(r'%([^%]+)%'), (match) {
      final raw = match.group(1);
      if (raw == null || raw.isEmpty) {
        return match.group(0) ?? '';
      }
      final value = env[raw] ?? env[raw.toUpperCase()] ?? env[raw.toLowerCase()];
      return value ?? match.group(0)!;
    });
  }

  String get _localAppData =>
      Platform.environment['LOCALAPPDATA'] ?? p.join(_systemDrive, r'\Users', 'Public', 'AppData', 'Local');
  String get _appData =>
      Platform.environment['APPDATA'] ?? p.join(_systemDrive, r'\Users', 'Public', 'AppData', 'Roaming');
}
