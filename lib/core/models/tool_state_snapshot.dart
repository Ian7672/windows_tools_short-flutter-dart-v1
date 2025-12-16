class ToolStateSnapshot {
  const ToolStateSnapshot({
    this.servicesMatch,
    this.registryMatch,
    this.firewallMatch,
    this.notes = const [],
  });

  const ToolStateSnapshot.unknown()
      : servicesMatch = null,
        registryMatch = null,
        firewallMatch = null,
        notes = const [];

  final bool? servicesMatch;
  final bool? registryMatch;
  final bool? firewallMatch;
  final List<String> notes;

  bool get hasChecks =>
      servicesMatch != null || registryMatch != null || firewallMatch != null;

  bool get isApplied {
    final sections = <bool>[];
    if (servicesMatch != null) sections.add(servicesMatch!);
    if (registryMatch != null) sections.add(registryMatch!);
    if (firewallMatch != null) sections.add(firewallMatch!);
    if (sections.isEmpty) return false;
    return sections.every((element) => element);
  }

  Map<String, bool?> get sectionStates => {
        'Services': servicesMatch,
        'Registry': registryMatch,
        'Firewall': firewallMatch,
      };
}
