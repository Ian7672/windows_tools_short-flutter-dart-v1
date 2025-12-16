import '../models/tool_definition.dart';
import 'service_controller.dart';

const String googleUpdaterToolId = 'googleUpdater';

class FirewallResolution {
  const FirewallResolution({
    required this.actions,
    this.dynamicServiceNames = const <String>[],
  });

  final List<FirewallAction> actions;
  final List<String> dynamicServiceNames;
}

Future<FirewallResolution> resolveFirewallActions(
  ToolDefinition tool,
  WindowsServiceController controller,
) async {
  if (tool.id != googleUpdaterToolId) {
    return FirewallResolution(actions: tool.firewallActions);
  }

  final discovered = await controller.findServicesByPattern(
    namePrefix: 'googleupdater',
    nameContains: 'googleupdater',
    displayContains: 'google updater',
  );
  final actions = <FirewallAction>[];
  final seen = <String>{};
  final names = <String>[];

  for (final service in discovered) {
    final lower = service.name.toLowerCase();
    if (seen.add(lower)) {
      names.add(service.name);
      actions.add(
        FirewallAction(
          ruleName: 'Google Update - ${service.name} OUT',
          direction: 'out',
          serviceName: service.name,
          groupName: '',
        ),
      );
    }
  }

  for (final fallback in tool.firewallActions) {
    final key = fallback.usesProgram
        ? (fallback.programPath ?? '').toLowerCase()
        : fallback.serviceName.toLowerCase();
    if (key.isEmpty || seen.add(key)) {
      actions.add(fallback);
    }
  }

  return FirewallResolution(actions: actions, dynamicServiceNames: names);
}
