enum ToolRiskLevel { low, medium, high }

ToolRiskLevel toolRiskLevelFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'low':
      return ToolRiskLevel.low;
    case 'high':
      return ToolRiskLevel.high;
    case 'medium':
    default:
      return ToolRiskLevel.medium;
  }
}

enum RegistryValueKind { string, dword, qword }

RegistryValueKind registryValueKindFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'dword':
      return RegistryValueKind.dword;
    case 'qword':
      return RegistryValueKind.qword;
    case 'string':
    default:
      return RegistryValueKind.string;
  }
}

enum ServiceStartType { automatic, manual, disabled }

ServiceStartType serviceStartTypeFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'disabled':
      return ServiceStartType.disabled;
    case 'manual':
      return ServiceStartType.manual;
    case 'automatic':
    default:
      return ServiceStartType.automatic;
  }
}

class RegistryAction {
  const RegistryAction({
    required this.hive,
    required this.path,
    required this.valueName,
    required this.valueKind,
    required this.data,
    required this.deleteValue,
  });

  final String hive;
  final String path;
  final String valueName;
  final RegistryValueKind valueKind;
  final String? data;
  final bool deleteValue;
}

class FirewallAction {
  const FirewallAction({
    required this.ruleName,
    required this.direction,
    required this.groupName,
    this.serviceName = '',
    this.programPath,
  });

  final String ruleName;
  final String direction;
  final String serviceName;
  final String groupName;
  final String? programPath;

  bool get usesProgram =>
      programPath != null && programPath!.trim().isNotEmpty;
}

class ServiceAction {
  const ServiceAction({
    required this.serviceName,
    this.targetStartType,
    this.stopService = false,
    this.startService = false,
  });

  final String serviceName;
  final ServiceStartType? targetStartType;
  final bool stopService;
  final bool startService;
}

class ToolDefinition {
  const ToolDefinition({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.requiresAdmin,
    required this.riskLevel,
    required this.allowCancel,
    required this.serviceActions,
    required this.registryActions,
    required this.firewallActions,
    this.localizedTitles = const <String, String>{},
    this.localizedDescriptions = const <String, String>{},
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final bool requiresAdmin;
  final ToolRiskLevel riskLevel;
  final bool allowCancel;
  final List<ServiceAction> serviceActions;
  final List<RegistryAction> registryActions;
  final List<FirewallAction> firewallActions;
  final Map<String, String> localizedTitles;
  final Map<String, String> localizedDescriptions;

  bool get hasConfiguredActions =>
      serviceActions.isNotEmpty ||
      registryActions.isNotEmpty ||
      firewallActions.isNotEmpty;

  ToolDefinition copyWith({
    String? title,
    String? description,
    bool? requiresAdmin,
    ToolRiskLevel? riskLevel,
    bool? allowCancel,
    List<ServiceAction>? serviceActions,
    List<RegistryAction>? registryActions,
    List<FirewallAction>? firewallActions,
    Map<String, String>? localizedTitles,
    Map<String, String>? localizedDescriptions,
  }) {
    return ToolDefinition(
      id: id,
      title: title ?? this.title,
      category: category,
      description: description ?? this.description,
      requiresAdmin: requiresAdmin ?? this.requiresAdmin,
      riskLevel: riskLevel ?? this.riskLevel,
      allowCancel: allowCancel ?? this.allowCancel,
      serviceActions: serviceActions ?? this.serviceActions,
      registryActions: registryActions ?? this.registryActions,
      firewallActions: firewallActions ?? this.firewallActions,
      localizedTitles: localizedTitles ?? this.localizedTitles,
      localizedDescriptions: localizedDescriptions ?? this.localizedDescriptions,
    );
  }

  static ToolDefinition fromJson(Map<String, dynamic> json) {
    final serviceActionsJson =
        json['serviceActions'] as List<dynamic>? ?? const [];
    final registryActionsJson =
        json['registryActions'] as List<dynamic>? ?? const [];
    final localizedTitles = _parseLocalizedMap(json['localizedTitles']);
    final localizedDescriptions =
        _parseLocalizedMap(json['localizedDescriptions']);
    return ToolDefinition(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Tool',
      category: json['category'] as String? ?? 'other',
      description: json['description'] as String? ?? '',
      requiresAdmin: json['requiresAdmin'] as bool? ?? false,
      riskLevel: toolRiskLevelFromString(json['riskLevel'] as String?),
      allowCancel: json['allowCancel'] as bool? ?? true,
      serviceActions: serviceActionsJson
          .map(
            (item) => ServiceAction(
              serviceName: (item as Map<String, dynamic>)['serviceName']
                      as String? ??
                  '',
              targetStartType: (item['startType'] as String?) == null
                  ? null
                  : serviceStartTypeFromString(item['startType'] as String?),
              stopService: item['stopService'] as bool? ?? false,
              startService: item['startService'] as bool? ?? false,
            ),
          )
          .where((action) => action.serviceName.isNotEmpty)
          .toList(),
      registryActions: registryActionsJson
          .map(
            (item) => RegistryAction(
              hive: (item as Map<String, dynamic>)['hive'] as String? ?? 'HKLM',
              path: item['path'] as String? ?? '',
              valueName: item['valueName'] as String? ?? '',
              valueKind:
                  registryValueKindFromString(item['type'] as String? ?? 'string'),
              data: item['data'] as String?,
              deleteValue: item['deleteValue'] as bool? ?? false,
            ),
          )
          .where((action) => action.path.isNotEmpty)
          .toList(),
      firewallActions: (json['firewallActions'] as List<dynamic>? ?? const [])
          .map(
            (item) => FirewallAction(
              ruleName: (item as Map<String, dynamic>)['ruleName'] as String? ?? '',
              direction: item['direction'] as String? ?? 'out',
              groupName: item['group'] as String? ?? 'LWT',
              serviceName: item['serviceName'] as String? ?? '',
              programPath: item['programPath'] as String?,
            ),
          )
          .where((action) =>
              action.ruleName.isNotEmpty && action.serviceName.isNotEmpty)
          .toList(),
      localizedTitles: localizedTitles,
      localizedDescriptions: localizedDescriptions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'requiresAdmin': requiresAdmin,
      'riskLevel': riskLevel.name,
      'allowCancel': allowCancel,
      'serviceActions': serviceActions
          .map((action) => {
                'serviceName': action.serviceName,
                'startType': action.targetStartType?.name,
                'stopService': action.stopService,
                'startService': action.startService,
              })
          .toList(),
      'registryActions': registryActions
          .map((action) => {
                'hive': action.hive,
                'path': action.path,
                'valueName': action.valueName,
                'type': action.valueKind.name,
                'data': action.data,
                'deleteValue': action.deleteValue,
              })
          .toList(),
      'firewallActions': firewallActions
          .map((action) => {
                'ruleName': action.ruleName,
                'direction': action.direction,
                'group': action.groupName,
                'serviceName': action.serviceName,
                'programPath': action.programPath,
              })
          .toList(),
      'localizedTitles': localizedTitles,
      'localizedDescriptions': localizedDescriptions,
    };
  }
}

Map<String, String> _parseLocalizedMap(dynamic raw) {
  if (raw is Map) {
    return raw.map(
      (key, value) => MapEntry(
        key.toString(),
        value?.toString() ?? '',
      ),
    );
  }
  return <String, String>{};
}
