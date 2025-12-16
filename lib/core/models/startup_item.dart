enum StartupSource {
  hkcuRun('HKCU Run'),
  hkcuRun32('HKCU Run (32-bit)'),
  hkcuRunOnce('HKCU RunOnce'),
  hklmRun('HKLM Run'),
  hklmRun32('HKLM Run (32-bit)'),
  hklmRunOnce('HKLM RunOnce'),
  startupFolderUser('Startup Folder (User)'),
  startupFolderCommon('Startup Folder (Common)'),
  scheduledTask('Scheduled Task');

  const StartupSource(this.label);
  final String label;
}

class StartupItem {
  const StartupItem({
    required this.name,
    required this.command,
    required this.location,
    required this.source,
    required this.enabled,
    required this.allowlisted,
    this.shortcutTarget,
    this.oneTime = false,
    this.autorunsDisabled = false,
    this.note,
  });

  final String name;
  final String command;
  final String location;
  final StartupSource source;
  final bool enabled;
  final bool allowlisted;
  final String? shortcutTarget;
  final bool oneTime;
  final bool autorunsDisabled;
  final String? note;

  Map<String, dynamic> toJson() => {
    'name': name,
    'command': command,
    'location': location,
    'source': source.name,
    'enabled': enabled,
    'allowlisted': allowlisted,
    'shortcutTarget': shortcutTarget,
    'oneTime': oneTime,
    'autorunsDisabled': autorunsDisabled,
    'note': note,
  };

  factory StartupItem.fromJson(Map<String, dynamic> json) {
    return StartupItem(
      name: json['name'] as String? ?? '',
      command: json['command'] as String? ?? '',
      location: json['location'] as String? ?? '',
      source: StartupSource.values.firstWhere(
        (source) => source.name == (json['source'] as String? ?? ''),
        orElse: () => StartupSource.hkcuRun,
      ),
      enabled: json['enabled'] as bool? ?? true,
      allowlisted: json['allowlisted'] as bool? ?? false,
      shortcutTarget: json['shortcutTarget'] as String?,
      oneTime: json['oneTime'] as bool? ?? false,
      autorunsDisabled: json['autorunsDisabled'] as bool? ?? false,
      note: json['note'] as String?,
    );
  }
}
