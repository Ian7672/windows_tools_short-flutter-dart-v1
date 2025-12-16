import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/cleaner/cleaner_controller.dart';
import 'controllers/tool_runner_controller.dart';
import 'controllers/tools_manifest_controller.dart';
import 'models/app_settings.dart';
import 'models/run_log_entry.dart';
import 'models/tool_definition.dart';
import 'models/tool_run_state.dart';
import 'models/tool_state_snapshot.dart';
import 'models/tools_manifest.dart';
import 'services/admin_service.dart';
import 'services/app_paths.dart';
import 'services/backup_service.dart';
import 'services/executable_scanner.dart';
import 'services/firewall_service.dart';
import 'services/installed_apps_scanner.dart';
import 'services/junk_cleaner_service.dart';
import 'services/logs_service.dart';
import 'services/registry_service.dart';
import 'services/service_controller.dart';
import 'services/settings_service.dart';
import 'services/startup_manager_service.dart';
import 'services/tool_handlers.dart';
import 'services/tool_state_service.dart';
import 'services/tools_manifest_repository.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('SharedPreferences missing'),
);

final packageInfoProvider = Provider<PackageInfo>(
  (ref) => throw UnimplementedError('PackageInfo missing'),
);

final appPathsProvider = Provider<AppPaths>(
  (ref) => throw UnimplementedError('App paths missing'),
);

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsController(prefs);
});

final adminServiceProvider = Provider<AdminService>(
  (ref) => const AdminService(),
);

final adminStatusProvider =
    StateNotifierProvider<AdminStatusController, AsyncValue<bool>>((ref) {
  final service = ref.watch(adminServiceProvider);
  return AdminStatusController(service);
});

final toolsManifestRepositoryProvider =
    Provider<ToolsManifestRepository>((ref) {
  final paths = ref.watch(appPathsProvider);
  return ToolsManifestRepository(paths);
});

final toolsManifestControllerProvider = StateNotifierProvider<
    ToolsManifestController, AsyncValue<ToolsManifest>>((ref) {
  final repo = ref.watch(toolsManifestRepositoryProvider);
  return ToolsManifestController(repo);
});

final logsServiceProvider = Provider<LogsService>((ref) {
  final paths = ref.watch(appPathsProvider);
  return LogsService(paths);
});

final logsControllerProvider =
    StateNotifierProvider<LogsController, List<RunLogEntry>>((ref) {
  final service = ref.watch(logsServiceProvider);
  return LogsController(service);
});

final backupServiceProvider = Provider<BackupService>((ref) {
  final paths = ref.watch(appPathsProvider);
  return BackupService(paths);
});

final registryServiceProvider = Provider<RegistryService>(
  (ref) => const RegistryService(),
);

final windowsServiceControllerProvider =
    Provider<WindowsServiceController>((ref) {
  return const WindowsServiceController();
});

final toolHandlerRegistryProvider = Provider<ToolHandlerRegistry>((ref) {
  final registry = ref.watch(registryServiceProvider);
  final services = ref.watch(windowsServiceControllerProvider);
  final backups = ref.watch(backupServiceProvider);
  final firewall = ref.watch(firewallServiceProvider);
  return ToolHandlerRegistry(
    ConfigurableToolHandler(registry, services, backups, firewall),
  );
});

final toolRunnerControllerProvider = StateNotifierProvider.family<
    ToolRunnerController, ToolRunState, String>((ref, toolId) {
  final handlerRegistry = ref.watch(toolHandlerRegistryProvider);
  final logsController = ref.watch(logsControllerProvider.notifier);
  final logsService = ref.watch(logsServiceProvider);
  return ToolRunnerController(
    toolId: toolId,
    handlerRegistry: handlerRegistry,
    logsController: logsController,
    logsService: logsService,
  );
});

final startupManagerServiceProvider =
    Provider<StartupManagerService>((ref) {
  final paths = ref.watch(appPathsProvider);
  return StartupManagerService(paths);
});

final junkCleanerServiceProvider = Provider<JunkCleanerService>(
  (ref) => const JunkCleanerService(),
);

final firewallServiceProvider = Provider<FirewallService>(
  (ref) => FirewallService(),
);

final executableScannerProvider = Provider<ExecutableScanner>(
  (ref) => const ExecutableScanner(),
);

final installedAppsScannerProvider = Provider<InstalledAppsScanner>(
  (ref) => const InstalledAppsScanner(),
);

final toolStateServiceProvider = Provider<ToolStateService>((ref) {
  final registry = ref.watch(registryServiceProvider);
  final services = ref.watch(windowsServiceControllerProvider);
  final firewall = ref.watch(firewallServiceProvider);
  return ToolStateService(registry, services, firewall);
});

final startupCleanerControllerProvider =
    StateNotifierProvider<StartupCleanerController, StartupCleanerState>(
        (ref) {
  final service = ref.watch(startupManagerServiceProvider);
  final controller = StartupCleanerController(service);
  unawaited(controller.loadItems());
  return controller;
});

final junkCleanerControllerProvider =
    StateNotifierProvider<JunkCleanerController, JunkCleanerState>((ref) {
  final service = ref.watch(junkCleanerServiceProvider);
  final controller = JunkCleanerController(service);
  unawaited(controller.detectBrowsers());
  return controller;
});

final toolAppliedStateProvider =
    FutureProvider.family<ToolStateSnapshot, String>((ref, toolId) async {
  // Re-run detection when tool run state changes.
  ref.watch(toolRunnerControllerProvider(toolId));
  final manifestAsync = ref.watch(toolsManifestControllerProvider);
  final manifest = manifestAsync.value;
  if (manifest == null) {
    return const ToolStateSnapshot.unknown();
  }
  ToolDefinition? tool;
  for (final candidate in manifest.tools) {
    if (candidate.id == toolId) {
      tool = candidate;
      break;
    }
  }
  if (tool == null) {
    return const ToolStateSnapshot.unknown();
  }
  final inspector = ref.watch(toolStateServiceProvider);
  return inspector.inspect(tool);
});

class AdminStatusController extends StateNotifier<AsyncValue<bool>> {
  AdminStatusController(this._service)
      : super(const AsyncValue.loading()) {
    _refresh();
  }

  final AdminService _service;

  void _refresh() {
    try {
      final isAdmin = _service.isRunningAsAdmin();
      state = AsyncValue.data(isAdmin);
    } catch (err, stack) {
      state = AsyncValue.error(err, stack);
    }
  }

  Future<void> recheck() async {
    _refresh();
  }

  Future<bool> requestElevation() async {
    return _service.restartAsAdministrator();
  }
}
