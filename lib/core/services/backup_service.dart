import 'dart:convert';
import 'dart:io';

import 'package:win32/win32.dart';

import '../models/tool_definition.dart';
import 'app_paths.dart';
import 'registry_service.dart';
import 'service_controller.dart';

class BackupPayload {
  BackupPayload({
    required this.toolId,
    required this.createdAt,
    required this.serviceSnapshots,
    required this.registrySnapshots,
    required this.filePath,
    required this.firewallRules,
  });

  final String toolId;
  final DateTime createdAt;
  final List<ServiceSnapshot> serviceSnapshots;
  final List<RegistrySnapshot> registrySnapshots;
  final String filePath;
  final List<String> firewallRules;
}

class BackupService {
  BackupService(this._paths);

  final AppPaths _paths;

  Future<BackupPayload> createBackup({
    required String toolId,
    required List<ServiceSnapshot> services,
    required List<RegistrySnapshot> registry,
    required List<String> firewallRules,
  }) async {
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final fileName = '${toolId}_$timestamp.json';
    final file = File('${_paths.backupsDir.path}\\$fileName');
    final data = {
      'toolId': toolId,
      'createdAt': DateTime.now().toIso8601String(),
      'services': services.map((s) => s.toJson()).toList(),
      'registry': registry.map((r) => r.toJson()).toList(),
      'firewall': firewallRules,
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return BackupPayload(
      toolId: toolId,
      createdAt: DateTime.now(),
      serviceSnapshots: services,
      registrySnapshots: registry,
      filePath: file.path,
      firewallRules: firewallRules,
    );
  }

  Future<BackupPayload?> loadLatest(String toolId) async {
    final backups = _paths.backupsDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.contains(toolId))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    if (backups.isEmpty) {
      return null;
    }
    final latest = backups.first;
    final raw = jsonDecode(await latest.readAsString()) as Map<String, dynamic>;
    final services = (raw['services'] as List<dynamic>? ?? const [])
        .map((item) => ServiceSnapshot(
              name: (item as Map<String, dynamic>)['name'] as String? ?? '',
              startType: serviceStartTypeFromString(
                item['startType'] as String? ?? 'automatic',
              ),
              state: item['state'] as int? ?? SERVICE_RUNNING,
            ))
        .toList();
    final registry = (raw['registry'] as List<dynamic>? ?? const [])
        .map((item) => RegistrySnapshot(
              hive: (item as Map<String, dynamic>)['hive'] as String? ?? 'HKLM',
              path: item['path'] as String? ?? '',
              valueName: item['valueName'] as String? ?? '',
              exists: item['exists'] as bool? ?? false,
              value: item['value'],
            ))
        .toList();
    return BackupPayload(
      toolId: toolId,
      createdAt: DateTime.tryParse(raw['createdAt'] as String? ?? '') ??
          DateTime.now(),
      serviceSnapshots: services,
      registrySnapshots: registry,
      filePath: latest.path,
      firewallRules: (raw['firewall'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
