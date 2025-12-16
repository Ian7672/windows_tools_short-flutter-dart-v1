import '../models/tool_definition.dart';
import 'backup_service.dart';
import 'firewall_actions_resolver.dart';
import 'firewall_service.dart';
import 'registry_service.dart';
import 'service_controller.dart';

class ToolExecutionResult {
  ToolExecutionResult({
    required this.success,
    required this.logs,
    this.errorCode,
    this.backupPath,
  });

  final bool success;
  final List<String> logs;
  final int? errorCode;
  final String? backupPath;
}

abstract class NativeToolHandler {
  Future<ToolExecutionResult> preview(ToolDefinition tool);
  Future<ToolExecutionResult> run(ToolDefinition tool);
  Future<ToolExecutionResult> restore(ToolDefinition tool);
}

class ConfigurableToolHandler implements NativeToolHandler {
  ConfigurableToolHandler(
    this._registryService,
    this._serviceController,
    this._backupService,
    this._firewallService,
  );

  final RegistryService _registryService;
  final WindowsServiceController _serviceController;
  final BackupService _backupService;
  final FirewallService _firewallService;

  bool _hasEffectiveActions(
    ToolDefinition tool,
    List<FirewallAction> resolvedFirewall,
  ) {
    return tool.serviceActions.isNotEmpty ||
        tool.registryActions.isNotEmpty ||
        resolvedFirewall.isNotEmpty;
  }

  @override
  Future<ToolExecutionResult> preview(ToolDefinition tool) async {
    final resolution = await resolveFirewallActions(tool, _serviceController);
    final resolvedFirewall = resolution.actions;
    if (!_hasEffectiveActions(tool, resolvedFirewall)) {
      return ToolExecutionResult(
        success: false,
        logs: ['No service, registry, or firewall actions configured.'],
      );
    }
    final lines = <String>['Preview for ${tool.title}:'];
    if (tool.serviceActions.isNotEmpty) {
      lines.add('Service changes:');
      for (final action in tool.serviceActions) {
        final buffer = StringBuffer(' - ${action.serviceName}');
        if (action.targetStartType != null) {
          buffer.write(' -> startType ${action.targetStartType!.name}');
        }
        if (action.stopService) buffer.write(' (stop)');
        if (action.startService) buffer.write(' (start)');
        lines.add(buffer.toString());
      }
    }
    if (tool.registryActions.isNotEmpty) {
      lines.add('Registry changes:');
      for (final action in tool.registryActions) {
        final deleteSuffix = action.deleteValue ? ' [delete]' : '';
        lines.add(' - ${action.hive}\\${action.path}\\${action.valueName}$deleteSuffix');
      }
    }
    if (resolvedFirewall.isNotEmpty) {
      lines.add('Firewall rules:');
      for (final action in resolvedFirewall) {
        lines.add(
          ' - ${action.ruleName} (${action.direction.toUpperCase()} service=${action.serviceName})',
        );
      }
    }
    return ToolExecutionResult(success: true, logs: lines);
  }

  @override
  Future<ToolExecutionResult> run(ToolDefinition tool) async {
    final resolution = await resolveFirewallActions(tool, _serviceController);
    final resolvedFirewallActions = resolution.actions;
    if (!_hasEffectiveActions(tool, resolvedFirewallActions)) {
      return ToolExecutionResult(
        success: false,
        logs: ['Tool is not configured. Update manifest to define actions.'],
        errorCode: 0,
      );
    }
    final logs = <String>[];
    final registrySnapshots = <RegistrySnapshot>[];
    final serviceSnapshots = <ServiceSnapshot>[];
    final firewallRuleNames =
        resolvedFirewallActions.map((action) => action.ruleName).toList();

    for (final action in tool.registryActions) {
      final snapshot = await _registryService.snapshot(action);
      if (snapshot != null) {
        registrySnapshots.add(snapshot);
      }
    }
    for (final action in tool.serviceActions) {
      final snapshot = await _serviceController.snapshot(action.serviceName);
      if (snapshot != null) {
        serviceSnapshots.add(snapshot);
      }
    }

    final backup = await _backupService.createBackup(
      toolId: tool.id,
      services: serviceSnapshots,
      registry: registrySnapshots,
      firewallRules: firewallRuleNames,
    );
    logs.add('Backup stored: ${backup.filePath}');

    for (final action in tool.serviceActions) {
      final result = await _serviceController.applyAction(action);
      logs.add('${action.serviceName}: ${result.message}');
      if (!result.success) {
        return ToolExecutionResult(
          success: false,
          logs: logs,
          errorCode: result.errorCode,
          backupPath: backup.filePath,
        );
      }
    }

    for (final action in tool.registryActions) {
      final result = await _registryService.apply(action);
      logs.add(
        '${action.hive}\\${action.path}\\${action.valueName}: ${result.message}',
      );
      if (!result.success) {
        return ToolExecutionResult(
          success: false,
          logs: logs,
          errorCode: -1,
          backupPath: backup.filePath,
        );
      }
    }

    if (resolvedFirewallActions.isNotEmpty) {
      if (tool.id == googleUpdaterToolId &&
          resolution.dynamicServiceNames.isNotEmpty) {
        final names = resolution.dynamicServiceNames.join(', ');
        logs.add('Detected Google updater services: $names');
      }
      logs.add('Applying firewall rules...');
      final fwResults = await _firewallService.applyActions(
        resolvedFirewallActions,
      );
      for (final result in fwResults) {
        logs.add(result.message);
        if (!result.success) {
          return ToolExecutionResult(
            success: false,
            logs: logs,
            errorCode: result.errorCode ?? -2,
            backupPath: backup.filePath,
          );
        }
      }
    }

    logs.add('All actions completed.');
    return ToolExecutionResult(
      success: true,
      logs: logs,
      backupPath: backup.filePath,
    );
  }

  @override
  Future<ToolExecutionResult> restore(ToolDefinition tool) async {
    final backup = await _backupService.loadLatest(tool.id);
    if (backup == null) {
      return ToolExecutionResult(
        success: false,
        logs: ['No backup found for ${tool.id}'],
      );
    }
    final logs = <String>['Restoring from ${backup.filePath}'];
    for (final snapshot in backup.serviceSnapshots) {
      final result = await _serviceController.restore(snapshot);
      logs.add('${snapshot.name}: ${result.message}');
      if (!result.success) {
        return ToolExecutionResult(
          success: false,
          logs: logs,
          errorCode: result.errorCode,
        );
      }
    }
    for (final snapshot in backup.registrySnapshots) {
      final result = await _registryService.restore(snapshot);
      logs.add('${snapshot.hive}\\${snapshot.path}\\${snapshot.valueName}: ${result.message}');
      if (!result.success) {
        return ToolExecutionResult(
          success: false,
          logs: logs,
          errorCode: -1,
        );
      }
    }
    if (backup.firewallRules.isNotEmpty) {
      logs
          .add('Removing ${backup.firewallRules.length} firewall rule(s) from backup.');
      final fwResults =
          await _firewallService.removeRules(backup.firewallRules);
      for (final result in fwResults) {
        logs.add(result.message);
        if (!result.success) {
          return ToolExecutionResult(
            success: false,
            logs: logs,
            errorCode: result.errorCode ?? -2,
          );
        }
      }
    }
    logs.add('Restore complete.');
    return ToolExecutionResult(success: true, logs: logs);
  }
}

class ToolHandlerRegistry {
  ToolHandlerRegistry(this._handler);

  final ConfigurableToolHandler _handler;

  NativeToolHandler resolve(ToolDefinition tool) {
    // Future handlers can be mapped here per toolId.
    return _handler;
  }
}
