import 'package:win32/win32.dart' as win32;

import '../models/tool_definition.dart';
import '../models/tool_state_snapshot.dart';
import 'firewall_actions_resolver.dart';
import 'firewall_service.dart';
import 'registry_service.dart';
import 'service_controller.dart';

class ToolStateService {
  ToolStateService(
    this._registryService,
    this._serviceController,
    this._firewallService,
  );

  final RegistryService _registryService;
  final WindowsServiceController _serviceController;
  final FirewallService _firewallService;

  Future<ToolStateSnapshot> inspect(ToolDefinition tool) async {
    final resolution = await resolveFirewallActions(
      tool,
      _serviceController,
    );
    final resolvedFirewall = resolution.actions;

    bool? servicesMatch;
    bool? registryMatch;
    bool? firewallMatch;
    final notes = <String>[];

    if (tool.serviceActions.isNotEmpty) {
      servicesMatch = true;
      for (final action in tool.serviceActions) {
        final snapshot = await _serviceController.snapshot(action.serviceName);
        if (snapshot == null) {
          servicesMatch = false;
          notes.add('${action.serviceName}: service not found');
          continue;
        }
        if (action.targetStartType != null &&
            snapshot.startType != action.targetStartType) {
          servicesMatch = false;
          notes.add(
            '${action.serviceName}: start=${snapshot.startType.name} expected ${action.targetStartType!.name}',
          );
        }
        if (action.stopService &&
            snapshot.state != win32.SERVICE_STOPPED) {
          servicesMatch = false;
          notes.add('${action.serviceName}: expected stopped');
        }
        if (action.startService &&
            snapshot.state != win32.SERVICE_RUNNING) {
          servicesMatch = false;
          notes.add('${action.serviceName}: expected running');
        }
      }
    }

    if (tool.registryActions.isNotEmpty) {
      registryMatch = true;
      for (final action in tool.registryActions) {
        final snapshot = await _registryService.snapshot(action);
        final target = '${action.hive}\\${action.path}\\${action.valueName}';
        if (snapshot == null) {
          registryMatch = false;
          notes.add('$target: cannot read');
          continue;
        }
        if (action.deleteValue) {
          if (snapshot.exists) {
            registryMatch = false;
            notes.add('$target: value present (expected removed)');
          }
          continue;
        }
        if (!snapshot.exists) {
          registryMatch = false;
          notes.add('$target: value missing');
          continue;
        }
        if (!_matchesRegistryValue(action, snapshot.value)) {
          registryMatch = false;
          notes.add('$target: value mismatch');
        }
      }
    }

    if (tool.id == googleUpdaterToolId &&
        resolution.dynamicServiceNames.isNotEmpty) {
      notes.add(
        'Detected Google updater services: ${resolution.dynamicServiceNames.join(', ')}',
      );
    }

    if (resolvedFirewall.isNotEmpty) {
      firewallMatch = true;
      for (final action in resolvedFirewall) {
        final exists = await _firewallService.ruleExists(action.ruleName);
        if (!exists) {
          firewallMatch = false;
          notes.add('${action.ruleName}: firewall rule missing');
        }
      }
    } else if (tool.id == googleUpdaterToolId) {
      notes.add('No Google updater services detected (rules pending).');
    }

    return ToolStateSnapshot(
      servicesMatch: servicesMatch,
      registryMatch: registryMatch,
      firewallMatch: firewallMatch,
      notes: notes,
    );
  }

  bool _matchesRegistryValue(RegistryAction action, Object? current) {
    switch (action.valueKind) {
      case RegistryValueKind.string:
        final normalized = (current ?? '').toString();
        return normalized == (action.data ?? '');
      case RegistryValueKind.dword:
      case RegistryValueKind.qword:
        final expected = int.tryParse(action.data ?? '0') ?? 0;
        if (current is int) {
          return current == expected;
        }
        if (current is BigInt) {
          return current.toInt() == expected;
        }
        return false;
    }
  }
}
