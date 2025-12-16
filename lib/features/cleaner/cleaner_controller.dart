import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/browser_entry.dart';
import '../../core/models/junk_entries.dart';
import '../../core/models/startup_item.dart';
import '../../core/services/junk_cleaner_service.dart';
import '../../core/services/startup_manager_service.dart';

class StartupCleanerState {
  const StartupCleanerState({
    required this.items,
    required this.isLoading,
    required this.lastDisabled,
    required this.lastBackupPath,
    required this.message,
  });

  final List<StartupItem> items;
  final bool isLoading;
  final List<StartupItem> lastDisabled;
  final String? lastBackupPath;
  final String? message;

  StartupCleanerState copyWith({
    List<StartupItem>? items,
    bool? isLoading,
    List<StartupItem>? lastDisabled,
    String? lastBackupPath,
    String? message,
  }) {
    return StartupCleanerState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      lastDisabled: lastDisabled ?? this.lastDisabled,
      lastBackupPath: lastBackupPath ?? this.lastBackupPath,
      message: message,
    );
  }

  factory StartupCleanerState.initial() => const StartupCleanerState(
        items: <StartupItem>[],
        isLoading: false,
        lastDisabled: <StartupItem>[],
        lastBackupPath: null,
        message: null,
      );
}

class StartupCleanerController
    extends StateNotifier<StartupCleanerState> {
  StartupCleanerController(this._service)
      : super(StartupCleanerState.initial());

  final StartupManagerService _service;

  Future<void> loadItems() async {
    state = state.copyWith(isLoading: true, message: null);
    try {
      final result = await _service.loadAll();
      state = state.copyWith(
        items: result,
        isLoading: false,
      );
    } catch (err) {
      state = state.copyWith(
        isLoading: false,
        message: 'Failed to load startup entries: $err',
      );
    }
  }

  Future<void> disableAllExceptAllowlist() async {
    state = state.copyWith(isLoading: true, message: null);
    try {
      final result = await _service.disableNonAllowlisted();
      state = state.copyWith(
        isLoading: false,
        lastDisabled: result.disabledItems,
        lastBackupPath: result.backupPath,
        message:
            'Disabled ${result.disabledItems.length} items. Backup saved to ${result.backupPath}',
      );
      await loadItems();
    } catch (err) {
      state = state.copyWith(
        isLoading: false,
        message: 'Failed to disable startup items: $err',
      );
    }
  }

  Future<void> restoreBackup() async {
    state = state.copyWith(isLoading: true, message: null);
    try {
      final restored = await _service.restoreLatestBackup();
      state = state.copyWith(
        isLoading: false,
        message: restored
            ? 'Restore complete.'
            : 'No backup found to restore.',
      );
      await loadItems();
    } catch (err) {
      state = state.copyWith(
        isLoading: false,
        message: 'Failed to restore backup: $err',
      );
    }
  }
}

class JunkCleanerState {
  const JunkCleanerState({
    required this.scanResult,
    required this.isScanning,
    required this.isCleaning,
    required this.currentScanPath,
    required this.includeRecycleBin,
    required this.cleanWindowsUpdate,
    required this.cleanTemporaryInstall,
    required this.cleanDriverPackages,
    required this.cleanPreviousInstalls,
    required this.disableHibernation,
    required this.runComponentCleanup,
    required this.selectedBrowserIds,
    required this.detectedBrowsers,
    required this.isHibernationBusy,
    required this.message,
  });

  final JunkScanResult? scanResult;
  final bool isScanning;
  final bool isCleaning;
  final String? currentScanPath;
  final bool includeRecycleBin;
  final bool cleanWindowsUpdate;
  final bool cleanTemporaryInstall;
  final bool cleanDriverPackages;
  final bool cleanPreviousInstalls;
  final bool disableHibernation;
  final bool runComponentCleanup;
  final Set<String> selectedBrowserIds;
  final List<BrowserEntry> detectedBrowsers;
  final bool isHibernationBusy;
  final String? message;

  JunkCleanerState copyWith({
    JunkScanResult? scanResult,
    bool? isScanning,
    bool? isCleaning,
    String? currentScanPath,
    bool resetScanPath = false,
    bool? includeRecycleBin,
    bool? cleanWindowsUpdate,
    bool? cleanTemporaryInstall,
    bool? cleanDriverPackages,
    bool? cleanPreviousInstalls,
    bool? disableHibernation,
    bool? runComponentCleanup,
    Set<String>? selectedBrowserIds,
    List<BrowserEntry>? detectedBrowsers,
    bool? isHibernationBusy,
    String? message,
  }) {
    return JunkCleanerState(
      scanResult: scanResult ?? this.scanResult,
      isScanning: isScanning ?? this.isScanning,
      isCleaning: isCleaning ?? this.isCleaning,
      currentScanPath:
          resetScanPath ? null : (currentScanPath ?? this.currentScanPath),
      includeRecycleBin: includeRecycleBin ?? this.includeRecycleBin,
      cleanWindowsUpdate: cleanWindowsUpdate ?? this.cleanWindowsUpdate,
      cleanTemporaryInstall:
          cleanTemporaryInstall ?? this.cleanTemporaryInstall,
      cleanDriverPackages:
          cleanDriverPackages ?? this.cleanDriverPackages,
      cleanPreviousInstalls:
          cleanPreviousInstalls ?? this.cleanPreviousInstalls,
      disableHibernation: disableHibernation ?? this.disableHibernation,
      runComponentCleanup: runComponentCleanup ?? this.runComponentCleanup,
      selectedBrowserIds: selectedBrowserIds ?? this.selectedBrowserIds,
      detectedBrowsers: detectedBrowsers ?? this.detectedBrowsers,
      isHibernationBusy: isHibernationBusy ?? this.isHibernationBusy,
      message: message,
    );
  }

  factory JunkCleanerState.initial() => const JunkCleanerState(
        scanResult: null,
        isScanning: false,
        isCleaning: false,
        currentScanPath: null,
        includeRecycleBin: true,
        cleanWindowsUpdate: true,
        cleanTemporaryInstall: true,
        cleanDriverPackages: true,
        cleanPreviousInstalls: true,
        disableHibernation: true,
        runComponentCleanup: true,
        selectedBrowserIds: <String>{},
        detectedBrowsers: <BrowserEntry>[],
        isHibernationBusy: false,
        message: null,
      );
}

class JunkCleanerController extends StateNotifier<JunkCleanerState> {
  JunkCleanerController(this._service)
      : super(JunkCleanerState.initial());

  final JunkCleanerService _service;

  Future<void> detectBrowsers() async {
    final entries = await _service.detectBrowserData();
    final availableIds = entries.map((e) => e.id).toSet();
    final retained =
        state.selectedBrowserIds.where(availableIds.contains).toSet();
    final newSelection = retained.isEmpty ? availableIds : retained;
    state = state.copyWith(
      detectedBrowsers: entries,
      selectedBrowserIds: newSelection,
    );
  }

  bool isBrowserSelected(BrowserEntry entry) =>
      state.selectedBrowserIds.contains(entry.id);

  void toggleBrowser(BrowserEntry entry, bool selected) {
    final updated = Set<String>.from(state.selectedBrowserIds);
    if (selected) {
      updated.add(entry.id);
    } else {
      updated.remove(entry.id);
    }
    state = state.copyWith(selectedBrowserIds: updated);
  }

  void toggleRecycleBin(bool value) {
    state = state.copyWith(includeRecycleBin: value);
  }

  void updateOptions({
    bool? cleanWindowsUpdate,
    bool? cleanTemporaryInstall,
    bool? cleanDriverPackages,
    bool? cleanPreviousInstalls,
    bool? disableHibernation,
    bool? runComponentCleanup,
  }) {
    state = state.copyWith(
      cleanWindowsUpdate: cleanWindowsUpdate,
      cleanTemporaryInstall: cleanTemporaryInstall,
      cleanDriverPackages: cleanDriverPackages,
      cleanPreviousInstalls: cleanPreviousInstalls,
      disableHibernation: disableHibernation,
      runComponentCleanup: runComponentCleanup,
    );
  }

  Future<void> scan() async {
    state = state.copyWith(
      isScanning: true,
      message: null,
      currentScanPath: 'Preparing...',
    );
    try {
      final result = await _service.scan(
        includeRecycleBin: state.includeRecycleBin,
        onProgress: (path) {
          state = state.copyWith(currentScanPath: path);
        },
      );
      state = state.copyWith(
        isScanning: false,
        scanResult: result,
        message: 'Scan complete.',
        resetScanPath: true,
      );
    } catch (err) {
      state = state.copyWith(
        isScanning: false,
        message: 'Failed to scan directories: $err',
        resetScanPath: true,
      );
    }
  }

  Future<void> clean() async {
    final scanResult = state.scanResult;
    if (scanResult == null) {
      state = state.copyWith(message: 'Run scan first.');
      return;
    }

    state = state.copyWith(isCleaning: true, message: null);
    try {
      await _service.clean(
        scanResult,
        includeRecycleBin: state.includeRecycleBin,
      );
      final notes = <String>[];
      if (state.cleanWindowsUpdate) {
        await _service.cleanWindowsUpdateData();
        notes.add('Windows Update cleanup completed.');
      }
      if (state.cleanTemporaryInstall) {
        await _service.cleanTemporaryInstallFiles();
        notes.add('Temporary installation files removed.');
      }
      if (state.cleanDriverPackages) {
        await _service.cleanDriverPackages();
        notes.add('Driver package leftovers cleared.');
      }
      if (state.cleanPreviousInstalls) {
        await _service.cleanPreviousInstallations();
        notes.add('Previous Windows installations removed.');
      }
      if (state.disableHibernation) {
        await _service.disableHibernation();
        notes.add('Hibernation disabled and hiberfil.sys removed.');
      }
      if (state.runComponentCleanup) {
        await _service.cleanupComponentStore();
        notes.add('Component store temp data flushed.');
      }
      if (state.selectedBrowserIds.isNotEmpty) {
        await _service.cleanBrowserCaches(state.selectedBrowserIds);
        notes.add('Browser caches cleared.');
      }
      final refreshed = await _service.scan(
        includeRecycleBin: state.includeRecycleBin,
      );
      state = state.copyWith(
        isCleaning: false,
        scanResult: refreshed,
        message: [
          'Cleanup succeeded.',
          ...notes,
        ].join('\n'),
      );
    } catch (err) {
      state = state.copyWith(
        isCleaning: false,
        message: 'Cleanup failed: $err',
      );
    }
  }

  Future<void> enableHibernation() async {
    state = state.copyWith(isHibernationBusy: true, message: null);
    try {
      await _service.enableHibernation();
      state = state.copyWith(
        isHibernationBusy: false,
        message: 'Hibernation re-enabled.',
      );
    } catch (err) {
      state = state.copyWith(
        isHibernationBusy: false,
        message: 'Failed to enable hibernation: $err',
      );
    }
  }
}
