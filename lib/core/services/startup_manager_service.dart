import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart' as win32;
import 'package:win32_registry/win32_registry.dart';

import '../constants/app_strings.dart';
import '../models/startup_item.dart';
import 'app_paths.dart';

class StartupDisableResult {
  StartupDisableResult({required this.disabledItems, required this.backupPath});

  final List<StartupItem> disabledItems;
  final String backupPath;
}

class StartupManagerService {
  StartupManagerService(this._paths);

  final AppPaths _paths;
  final _ShortcutResolver _shortcutResolver = _ShortcutResolver();

  static const _hkcuRunPath = r'Software\Microsoft\Windows\CurrentVersion\Run';
  static const _hkcuRunOncePath =
      r'Software\Microsoft\Windows\CurrentVersion\RunOnce';
  static const _hklmRunPath = r'SOFTWARE\Microsoft\Windows\CurrentVersion\Run';
  static const _hklmRunOncePath =
      r'SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce';
  static const _hklmRun32Path =
      r'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run';
  static const _startupApprovedRunPath =
      r'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run';
  static const _startupApprovedRun32Path =
      r'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32';
  static const _startupApprovedFolderPath =
      r'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder';
  static const _autorunsSubkey = 'AutorunsDisabled';

  static const _registrySources = <_RegistryRunSource>[
    _RegistryRunSource(
      hive: RegistryHive.currentUser,
      path: _hkcuRunPath,
      approvedPath: _startupApprovedRunPath,
      source: StartupSource.hkcuRun,
    ),
    _RegistryRunSource(
      hive: RegistryHive.currentUser,
      path: _hkcuRunOncePath,
      approvedPath: _startupApprovedRunPath,
      source: StartupSource.hkcuRunOnce,
      oneTime: true,
      supportsAutoruns: false,
    ),
    _RegistryRunSource(
      hive: RegistryHive.localMachine,
      path: _hklmRunPath,
      approvedPath: _startupApprovedRunPath,
      source: StartupSource.hklmRun,
    ),
    _RegistryRunSource(
      hive: RegistryHive.localMachine,
      path: _hklmRunOncePath,
      approvedPath: _startupApprovedRunPath,
      source: StartupSource.hklmRunOnce,
      oneTime: true,
      supportsAutoruns: false,
    ),
    _RegistryRunSource(
      hive: RegistryHive.localMachine,
      path: _hklmRun32Path,
      approvedPath: _startupApprovedRun32Path,
      source: StartupSource.hklmRun32,
    ),
  ];

  Future<List<StartupItem>> loadAll({bool includeRunOnce = false}) async {
    final entries = <StartupItem>[];
    for (final source in _registrySources) {
      if (!includeRunOnce && source.oneTime) {
        continue;
      }
      entries.addAll(_readRegistryEntries(source));
    }
    entries.addAll(
      _readStartupFolder(_userStartupFolder(), StartupSource.startupFolderUser),
    );
    entries.addAll(
      _readStartupFolder(
        _commonStartupFolder(),
        StartupSource.startupFolderCommon,
      ),
    );

    final deduped = <String, StartupItem>{};
    for (final entry in entries) {
      final key = '${entry.source.name}:${entry.location.toLowerCase()}';
      deduped[key] = entry;
    }
    final list = deduped.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<StartupDisableResult> disableNonAllowlisted() async {
    final items = await loadAll();
    final toDisable = items.where((item) {
      if (item.oneTime) return false;
      if (item.autorunsDisabled) return false;
      if (!item.enabled) return false;
      return !item.allowlisted;
    }).toList();

    final backup = {
      'createdAt': DateTime.now().toIso8601String(),
      'items': toDisable.map((item) => item.toJson()).toList(),
    };
    final fileName =
        'startup_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final backupFile = File(p.join(_paths.backupsDir.path, fileName));
    await backupFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(backup),
    );

    for (final item in toDisable) {
      _setApprovedStateForItem(item, enabled: false);
    }

    return StartupDisableResult(
      disabledItems: toDisable,
      backupPath: backupFile.path,
    );
  }

  Future<bool> restoreLatestBackup() async {
    final backups =
        _paths.backupsDir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .toList()
          ..sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
          );
    if (backups.isEmpty) {
      return false;
    }
    final latest = backups.first;
    final data =
        jsonDecode(await latest.readAsString()) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>)
        .map((map) => StartupItem.fromJson(map as Map<String, dynamic>))
        .toList();
    for (final item in items) {
      _restoreItem(item);
    }
    return true;
  }

  List<StartupItem> _readRegistryEntries(_RegistryRunSource source) {
    RegistryKey? key;
    try {
      key = Registry.openPath(source.hive, path: source.path);
    } catch (_) {
      return const [];
    }
    final entries = <StartupItem>[];
    for (final value in key.values) {
      final command = _expandAndNormalize(_registryValueToString(value));
      final allowlisted = _isAllowlisted(command);
      final enabled = _isStartupApprovedEnabled(
        hive: source.hive,
        approvedPath: source.approvedPath,
        name: value.name,
      );
      entries.add(
        StartupItem(
          name: value.name,
          command: command,
          location: '${source.path}\\${value.name}',
          source: source.source,
          enabled: enabled,
          allowlisted: allowlisted,
          oneTime: source.oneTime,
          note: source.oneTime ? 'One-time (RunOnce)' : null,
        ),
      );
    }
    key.close();

    if (source.supportsAutoruns) {
      entries.addAll(_readAutorunsDisabled(source));
    }

    return entries;
  }

  List<StartupItem> _readAutorunsDisabled(_RegistryRunSource source) {
    final path = '${source.path}\\$_autorunsSubkey';
    RegistryKey? key;
    try {
      key = Registry.openPath(source.hive, path: path);
    } catch (_) {
      return const [];
    }
    final entries = <StartupItem>[];
    for (final value in key.values) {
      final command = _expandAndNormalize(_registryValueToString(value));
      entries.add(
        StartupItem(
          name: value.name,
          command: command,
          location: '$path\\${value.name}',
          source: source.source,
          enabled: false,
          allowlisted: _isAllowlisted(command),
          autorunsDisabled: true,
          note: 'Disabled via Autoruns',
        ),
      );
    }
    key.close();
    return entries;
  }

  List<StartupItem> _readStartupFolder(Directory folder, StartupSource source) {
    if (!folder.existsSync()) {
      return const [];
    }
    final entries = <StartupItem>[];
    final hive = source == StartupSource.startupFolderCommon
        ? RegistryHive.localMachine
        : RegistryHive.currentUser;
    for (final entity in folder.listSync()) {
      if (entity is! File) continue;
      final fileName = p.basename(entity.path);
      final resolved = _shortcutResolver.resolve(entity.path);
      final enabled = _isStartupApprovedEnabled(
        hive: hive,
        approvedPath: _startupApprovedFolderPath,
        name: fileName,
      );
      entries.add(
        StartupItem(
          name: fileName,
          command: resolved,
          location: entity.path,
          source: source,
          enabled: enabled,
          allowlisted: _isAllowlisted(resolved),
          shortcutTarget: resolved.toLowerCase() != entity.path.toLowerCase()
              ? resolved
              : null,
        ),
      );
    }
    return entries;
  }

  void _setApprovedStateForItem(StartupItem item, {required bool enabled}) {
    final hive = _hiveForSource(item.source);
    final approvedPath = _approvedPathForSource(item.source);
    if (hive == null || approvedPath == null) {
      return;
    }
    _setStartupApprovedState(
      hive: hive,
      approvedPath: approvedPath,
      name: item.name,
      enabled: enabled,
    );
  }

  void _restoreItem(StartupItem item) {
    _setApprovedStateForItem(item, enabled: true);
    if (item.autorunsDisabled) {
      _promoteAutorunsEntry(item);
    }
  }

  void _promoteAutorunsEntry(StartupItem item) {
    final hive = _hiveForSource(item.source);
    final basePath = _registryPathForSource(item.source);
    if (hive == null || basePath == null) return;
    final disabledPath = '$basePath\\$_autorunsSubkey';
    RegistryKey? disabledKey;
    RegistryKey? activeKey;
    try {
      disabledKey = Registry.openPath(
        hive,
        path: disabledPath,
        desiredAccessRights: AccessRights.allAccess,
      );
      final value = disabledKey.getValue(item.name);
      if (value == null) {
        return;
      }
      activeKey = Registry.openPath(
        hive,
        path: basePath,
        desiredAccessRights: AccessRights.allAccess,
      );
      activeKey.createValue(RegistryValue(item.name, value.type, value.data));
      disabledKey.deleteValue(item.name);
    } catch (_) {
      // ignored
    } finally {
      disabledKey?.close();
      activeKey?.close();
    }
  }

  bool _isStartupApprovedEnabled({
    required RegistryHive hive,
    required String approvedPath,
    required String name,
  }) {
    final data = _readStartupApprovedData(hive, approvedPath, name);
    if (data == null || data.length < 4) {
      return true;
    }
    final status = data[0];
    if (status == 0x03 || status == 0x07) {
      return false;
    }
    return true;
  }

  Uint8List? _readStartupApprovedData(
    RegistryHive hive,
    String approvedPath,
    String name,
  ) {
    RegistryKey? key;
    try {
      key = Registry.openPath(
        hive,
        path: approvedPath,
        desiredAccessRights: AccessRights.readOnly,
      );
      final value = key.getValue(name);
      if (value == null) {
        return null;
      }
      final data = value.data;
      if (data is Uint8List) {
        return data;
      }
      if (data is List<int>) {
        return Uint8List.fromList(data);
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      key?.close();
    }
  }

  void _setStartupApprovedState({
    required RegistryHive hive,
    required String approvedPath,
    required String name,
    required bool enabled,
  }) {
    RegistryKey? key;
    try {
      key = _openOrCreateKey(hive, approvedPath);
      final data = List<int>.filled(12, 0);
      data[0] = enabled ? 0x02 : 0x03;
      if (!enabled) {
        final ft = _currentFileTimeBytes();
        for (var i = 0; i < ft.length && (i + 4) < data.length; i++) {
          data[i + 4] = ft[i];
        }
      }
      key.createValue(
        RegistryValue(name, RegistryValueType.binary, Uint8List.fromList(data)),
      );
    } catch (_) {
      // swallow write errors
    } finally {
      key?.close();
    }
  }

  RegistryKey _openOrCreateKey(RegistryHive hive, String path) {
    try {
      return Registry.openPath(
        hive,
        path: path,
        desiredAccessRights: AccessRights.allAccess,
      );
    } catch (_) {
      final segments = path.split(r'\').where((segment) => segment.isNotEmpty);
      var current = Registry.openPath(
        hive,
        path: '',
        desiredAccessRights: AccessRights.allAccess,
      );
      for (final segment in segments) {
        final next = current.createKey(segment);
        current.close();
        current = next;
      }
      return current;
    }
  }

  RegistryHive? _hiveForSource(StartupSource source) {
    switch (source) {
      case StartupSource.hkcuRun:
      case StartupSource.hkcuRun32:
      case StartupSource.hkcuRunOnce:
      case StartupSource.startupFolderUser:
        return RegistryHive.currentUser;
      case StartupSource.hklmRun:
      case StartupSource.hklmRun32:
      case StartupSource.hklmRunOnce:
      case StartupSource.startupFolderCommon:
        return RegistryHive.localMachine;
      case StartupSource.scheduledTask:
        return null;
    }
  }

  String? _approvedPathForSource(StartupSource source) {
    switch (source) {
      case StartupSource.hkcuRun:
      case StartupSource.hkcuRunOnce:
      case StartupSource.hklmRun:
      case StartupSource.hklmRunOnce:
        return _startupApprovedRunPath;
      case StartupSource.hkcuRun32:
      case StartupSource.hklmRun32:
        return _startupApprovedRun32Path;
      case StartupSource.startupFolderUser:
      case StartupSource.startupFolderCommon:
        return _startupApprovedFolderPath;
      case StartupSource.scheduledTask:
        return null;
    }
  }

  String? _registryPathForSource(StartupSource source) {
    switch (source) {
      case StartupSource.hkcuRun:
        return _hkcuRunPath;
      case StartupSource.hkcuRunOnce:
        return _hkcuRunOncePath;
      case StartupSource.hklmRun:
        return _hklmRunPath;
      case StartupSource.hklmRunOnce:
        return _hklmRunOncePath;
      case StartupSource.hklmRun32:
        return _hklmRun32Path;
      case StartupSource.hkcuRun32:
      case StartupSource.startupFolderUser:
      case StartupSource.startupFolderCommon:
      case StartupSource.scheduledTask:
        return null;
    }
  }

  Directory _userStartupFolder() {
    final appData =
        Platform.environment['APPDATA'] ??
        p.join(_paths.root.path, 'fallback-startup');
    return Directory(
      p.join(
        appData,
        'Microsoft',
        'Windows',
        'Start Menu',
        'Programs',
        'Startup',
      ),
    );
  }

  Directory _commonStartupFolder() {
    final programData =
        Platform.environment['PROGRAMDATA'] ??
        p.join(_paths.root.path, 'fallback-common-startup');
    return Directory(
      p.join(
        programData,
        'Microsoft',
        'Windows',
        'Start Menu',
        'Programs',
        'StartUp',
      ),
    );
  }

  bool _isAllowlisted(String command) {
    final normalized = command.toLowerCase();
    return AppStrings.allowlistedStartupExecutables.any(
      (allowed) => normalized.contains(allowed.toLowerCase()),
    );
  }

  String _expandAndNormalize(String value) {
    final expanded = _expandEnvironmentVariables(value.trim());
    return expanded.trim();
  }

  String _expandEnvironmentVariables(String input) {
    if (!input.contains('%')) {
      return input;
    }
    final env = Platform.environment;
    return input.replaceAllMapped(RegExp(r'%([^%]+)%'), (match) {
      final rawKey = match.group(1);
      if (rawKey == null || rawKey.isEmpty) {
        return match.group(0) ?? '';
      }
      final key = rawKey;
      final value =
          env[key] ?? env[key.toUpperCase()] ?? env[key.toLowerCase()];
      return value ?? match.group(0)!;
    });
  }

  String _registryValueToString(RegistryValue value) {
    final Object data = value.data;
    if (data is String) return data;
    if (data is List<String>) return data.join(' ');
    if (data is List<int>) {
      return String.fromCharCodes(data.where((code) => code != 0));
    }
    return data.toString();
  }

  List<int> _currentFileTimeBytes() {
    final now = DateTime.now().toUtc();
    const fileTimeEpoch = 116444736000000000;
    final fileTime = now.microsecondsSinceEpoch * 10 + fileTimeEpoch;
    final data = ByteData(8)..setUint64(0, fileTime, Endian.little);
    return data.buffer.asUint8List();
  }
}

class _RegistryRunSource {
  const _RegistryRunSource({
    required this.hive,
    required this.path,
    required this.approvedPath,
    required this.source,
    this.oneTime = false,
    this.supportsAutoruns = true,
  });

  final RegistryHive hive;
  final String path;
  final String approvedPath;
  final StartupSource source;
  final bool oneTime;
  final bool supportsAutoruns;
}

class _ShortcutResolver {
  bool _initialized = false;

  void _ensureInitialized() {
    if (_initialized) return;
    final hr = win32.CoInitializeEx(nullptr, win32.COINIT_APARTMENTTHREADED);
    if (hr == win32.S_OK || hr == win32.S_FALSE) {
      _initialized = true;
    }
  }

  String resolve(String path) {
    if (!path.toLowerCase().endsWith('.lnk')) {
      return path;
    }
    final file = File(path);
    if (!file.existsSync()) return path;

    _ensureInitialized();
    if (!_initialized) return path;

    win32.ShellLink shellLink;
    try {
      shellLink = win32.ShellLink.createInstance();
    } on Exception {
      return path;
    }

    win32.IPersistFile persistFile;
    try {
      persistFile = win32.IPersistFile.from(shellLink);
    } on Exception {
      shellLink.release();
      return path;
    }

    final widePath = path.toNativeUtf16();
    final loadHr = persistFile.load(widePath, win32.STGM_READ);
    calloc.free(widePath);
    if (win32.FAILED(loadHr)) {
      persistFile.release();
      shellLink.release();
      return path;
    }

    final buffer = calloc<Uint16>(win32.MAX_PATH).cast<Utf16>();
    String resolved = path;
    final getPathHr = shellLink.getPath(buffer, win32.MAX_PATH, nullptr, 0);
    if (win32.SUCCEEDED(getPathHr)) {
      final target = buffer.toDartString();
      if (target.isNotEmpty) {
        resolved = target;
      }
    }

    calloc.free(buffer);
    persistFile.release();
    shellLink.release();

    return resolved;
  }
}
