import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions/tool_localizations.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/tool_definition.dart';
import '../../core/models/tool_run_state.dart';
import '../../core/models/tool_state_snapshot.dart';
import '../../core/providers.dart';
import '../../core/services/executable_scanner.dart';
import '../../core/services/firewall_actions_resolver.dart'
    show googleUpdaterToolId;
import '../../core/services/installed_apps_scanner.dart';
import '../../core/services/service_controller.dart';

class UpdaterPage extends ConsumerStatefulWidget {
  const UpdaterPage({super.key});

  @override
  ConsumerState<UpdaterPage> createState() => _UpdaterPageState();
}

class _UpdaterPageState extends ConsumerState<UpdaterPage> {
  String? _selectedToolId;
  bool _acknowledged = true;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final manifestState = ref.watch(toolsManifestControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final adminState = ref.watch(adminStatusProvider);
    final isAdmin = adminState.when(
      data: (value) => value,
      loading: () => false,
      error: (_, __) => false,
    );
    String tr(String key, String fallback) => t.text(key, fallback);

    return ScaffoldPage(
      header: PageHeader(
        title: Text(t.pageUpdaterTitle),
        commandBar: CommandBar(
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: Text(t.text('updaterReload', 'Reload manifest')),
              onPressed: () {
                ref.read(toolsManifestControllerProvider.notifier).refresh();
              },
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: Text(t.text('updaterAddCustom', 'Add custom block')),
              onPressed: _showAddCustomBlockDialog,
            ),
            if (!adminState.hasError)
              CommandBarButton(
                icon: const Icon(FluentIcons.shield),
                label: Text(t.text('generalRecheckAdmin', 'Re-check admin')),
                onPressed: () {
                  ref.read(adminStatusProvider.notifier).recheck();
                },
              ),
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.all(16),
        child: manifestState.when(
          data: (manifest) {
            final tools = manifest.tools.where((tool) {
              if (!settings.showHighRiskTools &&
                  tool.riskLevel == ToolRiskLevel.high) {
                return false;
              }
              return true;
            }).toList();

            if (tools.isEmpty) {
              return Center(
                child: Text(
                  t.text(
                    'updaterNoTools',
                    'No tools available. Configure assets/tools_manifest.json.',
                  ),
                ),
              );
            }

            _selectedToolId ??= tools.first.id;
            final selectedTool = tools.firstWhere(
              (tool) => tool.id == _selectedToolId,
              orElse: () => tools.first,
            );

            final runState =
                ref.watch(toolRunnerControllerProvider(selectedTool.id));
            final runner =
                ref.read(toolRunnerControllerProvider(selectedTool.id).notifier);
            final appliedState =
                ref.watch(toolAppliedStateProvider(selectedTool.id));
            final bool? detectedApplied = appliedState.maybeWhen(
              data: (snapshot) =>
                  snapshot.hasChecks ? snapshot.isApplied : null,
              orElse: () => null,
            );
            final effectiveApplied = detectedApplied ?? runState.isApplied;

            final needsAck =
                (selectedTool.requiresAdmin && settings.requireAdminConfirmation) ||
                    selectedTool.riskLevel == ToolRiskLevel.high;

            final canRun = runState.status != ToolRunStatus.running &&
                (!needsAck || _acknowledged) &&
                (!selectedTool.requiresAdmin || isAdmin);

            return LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _ToolList(
                        tools: tools,
                        selectedTool: selectedTool,
                        onChanged: (tool) {
                          setState(() {
                            _selectedToolId = tool.id;
                            _acknowledged = true;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: _ToolDetailsPane(
                        tool: selectedTool,
                        state: runState,
                        appliedState: appliedState,
                        effectiveApplied: effectiveApplied,
                        acknowledged: _acknowledged,
                        needsAck: needsAck,
                        isAdmin: isAdmin,
                        adminState: adminState,
                        onAcknowledgedChanged: (value) {
                          setState(() {
                            _acknowledged = value;
                          });
                        },
                        onPreview: runState.status == ToolRunStatus.running
                            ? null
                            : () => runner.preview(selectedTool),
                        onRun: canRun ? () => runner.runTool(selectedTool) : null,
                        onRestore: runState.status == ToolRunStatus.running
                            ? null
                            : () => runner.restoreTool(selectedTool),
                      ),
                    ),
                  ],
                );
              },
            );
          },
          loading: () => const Center(child: ProgressRing()),
        error: (err, _) => InfoBar(
          title: Text(tr('updaterLoadFailed', 'Failed to load tools')),
          content: Text(err.toString()),
          severity: InfoBarSeverity.error,
        ),
        ),
      ),
    );
  }

  Future<void> _showAddCustomBlockDialog() async {
    final serviceController = ref.read(windowsServiceControllerProvider);
    final executableScanner = ref.read(executableScannerProvider);
    final appsScanner = ref.read(installedAppsScannerProvider);
    final notifier =
        ref.read(toolsManifestControllerProvider.notifier);
    final result = await showDialog<_CustomBlockRequest>(
      context: context,
      builder: (context) => _AddCustomBlockDialog(
        serviceController: serviceController,
        executableScanner: executableScanner,
        installedAppsScanner: appsScanner,
      ),
    );
    if (!mounted || result == null) return;
    if (result.serviceNames.isEmpty && result.programPaths.isEmpty) {
      return;
    }
    final newId = await notifier.addCustomFirewallTool(
      title: result.title,
      description: result.description,
      serviceNames: result.serviceNames,
      programPaths: result.programPaths,
    );
    setState(() {
      _selectedToolId = newId;
    });
  }
}

class _ToolList extends StatelessWidget {
  const _ToolList({
    required this.tools,
    required this.selectedTool,
    required this.onChanged,
  });

  final List<ToolDefinition> tools;
  final ToolDefinition selectedTool;
  final ValueChanged<ToolDefinition> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Card(
      child: ListView.builder(
        itemCount: tools.length,
        itemBuilder: (context, index) {
          final tool = tools[index];
          return ListTile.selectable(
            selected: tool.id == selectedTool.id,
            title: Text(tool.localizedTitle(t)),
            subtitle: Text(tool.localizedDescription(t)),
            trailing: tool.requiresAdmin
                ? const Icon(FluentIcons.shield_alert)
                : null,
            onPressed: () => onChanged(tool),
          );
        },
      ),
    );
  }
}

class _ToolDetailsPane extends StatefulWidget {
  const _ToolDetailsPane({
    required this.tool,
    required this.state,
    required this.appliedState,
    required this.effectiveApplied,
    required this.acknowledged,
    required this.needsAck,
    required this.isAdmin,
    required this.adminState,
    required this.onAcknowledgedChanged,
    required this.onPreview,
    required this.onRun,
    required this.onRestore,
  });

  final ToolDefinition tool;
  final ToolRunState state;
  final AsyncValue<ToolStateSnapshot> appliedState;
  final bool effectiveApplied;
  final bool acknowledged;
  final bool needsAck;
  final bool isAdmin;
  final AsyncValue<bool> adminState;
  final ValueChanged<bool> onAcknowledgedChanged;
  final VoidCallback? onPreview;
  final VoidCallback? onRun;
  final VoidCallback? onRestore;

  @override
  State<_ToolDetailsPane> createState() => _ToolDetailsPaneState();
}

class _ToolDetailsPaneState extends State<_ToolDetailsPane> {
  final ScrollController _logScrollController = ScrollController();

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    String tr(String key, String fallback) => t.text(key, fallback);
    final localizedTitle = widget.tool.localizedTitle(t);
    final localizedDescription = widget.tool.localizedDescription(t);
    final logs = widget.state.logLines.join('\n');
    final appliedState = widget.appliedState;
    final bool isApplied = widget.effectiveApplied;
    final riskTemplate = tr('updaterRiskLabel', 'RISK: {LEVEL}');
    final riskText = riskTemplate.replaceFirst(
      '{LEVEL}',
      widget.tool.riskLevel.name.toUpperCase(),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                  maxWidth: constraints.maxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedTitle,
                      style: FluentTheme.of(context).typography.subtitle,
                    ),
                    const SizedBox(height: 6),
                    Text(localizedDescription),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        InfoLabel(
                          label: tr('toolRiskLevel', 'Risk level'),
                          child: Text(widget.tool.riskLevel.name.toUpperCase()),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          widget.tool.requiresAdmin
                              ? tr('updaterRequiresAdmin', 'Requires Administrator')
                              : tr('updaterStandardPerms', 'Standard privileges'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        appliedState.when(
                          data: (snapshot) {
                            if (!snapshot.hasChecks) {
                              return _StatusChip(
                                icon: FluentIcons.info,
                                text: tr('updaterStateNotConfigured', 'STATE: NOT CONFIGURED'),
                              );
                            }
                            return _StatusChip(
                              icon: snapshot.isApplied
                                  ? FluentIcons.blocked2
                                  : FluentIcons.check_mark,
                              text: snapshot.isApplied
                                  ? tr('updaterCurrentDisabled', 'CURRENT: DISABLED')
                                  : tr('updaterCurrentEnabled', 'CURRENT: ENABLED'),
                            );
                          },
                          loading: () => _StatusChip(
                            icon: FluentIcons.sync,
                            text: tr('updaterCheckingState', 'CHECKING STATE...'),
                          ),
                          error: (_, __) => _StatusChip(
                            icon: FluentIcons.status_circle_exclamation,
                            text: tr('updaterStateUnknown', 'STATE UNKNOWN'),
                          ),
                        ),
                        _StatusChip(
                          icon: FluentIcons.block_contact,
                          text: tr('updaterTargetDisable', 'TARGET: DISABLE'),
                        ),
                        if (widget.tool.requiresAdmin)
                          _StatusChip(
                            icon: FluentIcons.shield,
                            text: tr('updaterAdminOnly', 'ADMIN ONLY'),
                          ),
                        _StatusChip(
                          icon: FluentIcons.warning,
                          text: riskText,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!widget.tool.hasConfiguredActions &&
                        widget.tool.id != googleUpdaterToolId)
                      InfoBar(
                        severity: InfoBarSeverity.warning,
                        title: Text(tr('updaterToolNotConfigured', 'Tool not configured')),
                        content: Text(
                          tr(
                            'updaterToolNotConfiguredHint',
                            'Add serviceActions, registryActions, or firewallActions in tools_manifest.json.',
                          ),
                        ),
                      ),
                    if (widget.tool.requiresAdmin && !widget.isAdmin)
                      InfoBar(
                        severity: InfoBarSeverity.error,
                        title: Text(tr('updaterElevationRequired', 'Elevation required')),
                        content: Text(
                          widget.adminState.isLoading
                              ? tr('updaterCheckingAdmin', 'Checking admin privileges...')
                              : tr('updaterRestartAsAdmin', 'Restart app as Administrator to run this tool.'),
                        ),
                      ),
                    const SizedBox(height: 12),
                    appliedState.when(
                      data: (snapshot) => _ToolStateBreakdown(snapshot: snapshot),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: ProgressRing(),
                      ),
                      error: (err, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '${tr('updaterStateCheckFailed', 'State check failed')}: $err',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ActionOverview(tool: widget.tool),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Button(
                  onPressed: widget.onPreview,
                  child: Text(tr('generalPreview', 'Preview')),
                ),
                FilledButton(
                  onPressed: isApplied ? widget.onRestore : widget.onRun,
                  child: Text(
                    isApplied
                        ? tr('generalEnable', 'Enable')
                        : tr('generalDisable', 'Disable'),
                  ),
                ),
                Button(
                  onPressed: logs.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: logs),
                          );
                        },
                  child: Text(tr('generalCopyLog', 'Copy log')),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                'updaterToggleExplanation',
                '{DISABLE} applies the selected blocks (services, firewall, registry). {ENABLE} restores backups to allow updates again.',
              )
                  .replaceAll('{DISABLE}', tr('generalDisable', 'Disable'))
                  .replaceAll('{ENABLE}', tr('generalEnable', 'Enable')),
              style: FluentTheme.of(context).typography.caption,
            ),
            const SizedBox(height: 12),
            if (widget.state.backupPath != null)
              Text(
                '${tr('generalLastBackup', 'Last backup')}: ${widget.state.backupPath}',
              ),
                    if (widget.state.errorCode != null)
                      Text(
                        '${tr('generalErrorCode', 'Error code')}: ${widget.state.errorCode}',
                      ),
                    Text(
                      '${tr('generalStatus', 'Status')}: ${widget.state.status.name}',
                    ),
                    if (widget.state.message != null)
                      Text(widget.state.message!),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: FluentTheme.of(context)
                                .resources
                                .controlStrokeColorSecondary,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: logs.isEmpty
                            ? Text(
                                tr(
                                  'updaterLogPlaceholder',
                                  'Preview, run, or restore to view logs here.',
                                ),
                              )
                            : RawScrollbar(
                                controller: _logScrollController,
                                thumbVisibility: true,
                                thickness: 10,
                                radius: const Radius.circular(8),
                                child: SingleChildScrollView(
                                  controller: _logScrollController,
                                  child: Text(
                                    logs,
                                    style: const TextStyle(
                                      fontFamily: 'Consolas',
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActionOverview extends StatelessWidget {
  const _ActionOverview({required this.tool});

  final ToolDefinition tool;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    String tr(String key, String fallback) => t.text(key, fallback);
    final sections = <Widget>[];
    if (tool.serviceActions.isNotEmpty) {
      sections.add(
        Expander(
          initiallyExpanded: false,
          leading: const Icon(FluentIcons.info),
          header: Text(
            '${tr('updaterServiceChanges', 'Service changes')} (${tool.serviceActions.length})',
          ),
          content: Column(
            children: tool.serviceActions.map((action) {
              final tags = <Widget>[];
              if (action.targetStartType != null) {
                tags.add(_ActionTag(
                  label: 'START=${action.targetStartType!.name.toUpperCase()}',
                ));
              }
              if (action.stopService) {
                tags.add(_ActionTag(label: tr('generalStop', 'STOP')));
              }
              if (action.startService) {
                tags.add(_ActionTag(label: tr('generalStart', 'START')));
              }
              return ListTile(
                leading: const Icon(FluentIcons.info),
                title: Text(action.serviceName),
                subtitle: tags.isEmpty
                    ? Text(tr('updaterNoServiceChange', 'No service control change'))
                    : Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: tags,
                      ),
              );
            }).toList(),
          ),
        ),
      );
    }
    if (tool.registryActions.isNotEmpty) {
      sections.add(
        Expander(
          initiallyExpanded: false,
          leading: const Icon(FluentIcons.info),
          header: Text(
            '${tr('updaterRegistryChanges', 'Registry changes')} (${tool.registryActions.length})',
          ),
          content: Column(
            children: tool.registryActions.map((action) {
              final target =
                  '${action.hive}\\${action.path}\\${action.valueName}';
              final isDelete = action.deleteValue;
              final setValueDescription = tr(
                'generalSetValue',
                'Set {VALUE}',
              ).replaceFirst(
                '{VALUE}',
                '${action.valueKind.name.toUpperCase()} = ${action.data ?? ''}',
              );
              return ListTile(
                leading: const Icon(FluentIcons.info),
                title: Text(target),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDelete
                          ? tr('generalDeleteValue', 'Delete value')
                          : setValueDescription,
                    ),
                    const SizedBox(height: 4),
                    _ActionTag(
                      label: isDelete
                          ? tr('generalDelete', 'DELETE')
                          : tr('generalSet', 'SET'),
                      color: isDelete
                          ? Colors.red.withValues(alpha: 0.2)
                          : Colors.green.withValues(alpha: 0.2),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      );
    }
    if (tool.firewallActions.isNotEmpty) {
      sections.add(
        Expander(
          initiallyExpanded: false,
          leading: const Icon(FluentIcons.info),
          header: Text(
            '${tr('updaterFirewallRules', 'Firewall rules')} (${tool.firewallActions.length})',
          ),
          content: Column(
            children: tool.firewallActions.map((action) {
              final targetText = action.usesProgram
                  ? tr('updaterProgramRule', 'Program {VALUE}')
                      .replaceFirst('{VALUE}', action.programPath ?? '')
                  : tr('updaterServiceRule', 'Service {VALUE}')
                      .replaceFirst('{VALUE}', action.serviceName);
              return ListTile(
                leading: const Icon(FluentIcons.info),
                title: Text(action.ruleName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$targetText -> ${action.direction.toUpperCase()}',
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        _ActionTag(label: action.direction.toUpperCase()),
                        _ActionTag(label: tr('generalBlock', 'BLOCK')),
                        if (action.usesProgram)
                          _ActionTag(label: tr('generalProgram', 'PROGRAM')),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      );
    }

    if (sections.isEmpty) {
      return Text(tr('updaterNoActions', 'No configured actions for this tool.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: sections
          .map((section) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: section,
              ))
          .toList(),
    );
  }
}

class _ToolStateBreakdown extends StatelessWidget {
  const _ToolStateBreakdown({required this.snapshot});

  final ToolStateSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    String tr(String key, String fallback) => t.text(key, fallback);
    if (!snapshot.hasChecks) {
      return Text(
        tr('updaterStateUnavailable', 'Current state unavailable until actions are configured.'),
      );
    }
    final theme = FluentTheme.of(context);
    final sections = snapshot.sectionStates.entries
        .where((entry) => entry.value != null)
        .map(
          (entry) => _StatusChip(
            icon: entry.value! ? FluentIcons.check_mark : FluentIcons.cancel,
            text:
                '${entry.key}: ${entry.value! ? tr('generalApplied', 'Applied') : tr('generalPending', 'Pending')}',
          ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          snapshot.isApplied
              ? tr('updaterCurrentStateDisabled', 'Current state: Disabled')
              : tr('updaterCurrentStateEnabled', 'Current state: Enabled'),
          style: theme.typography.bodyStrong,
        ),
        if (sections.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: sections,
          ),
        ],
        if (snapshot.notes.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...snapshot.notes.map(
            (note) => Text(
              '• $note',
              style: theme.typography.caption,
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionTag extends StatelessWidget {
  const _ActionTag({
    required this.label,
    this.color,
  });

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ??
        FluentTheme.of(context)
            .accentColor
            .withValues(alpha: 0.2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: resolvedColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: FluentTheme.of(context)
            .typography
            .caption
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.resources.controlStrokeColorDefault,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.typography.caption,
          ),
        ],
      ),
    );
  }
}

class _CustomBlockRequest {
  _CustomBlockRequest({
    required this.title,
    required this.description,
    required this.serviceNames,
    required this.programPaths,
  });

  final String title;
  final String description;
  final List<String> serviceNames;
  final List<String> programPaths;
}

class _AddCustomBlockDialog extends StatefulWidget {
  const _AddCustomBlockDialog({
    required this.serviceController,
    required this.executableScanner,
    required this.installedAppsScanner,
  });

  final WindowsServiceController serviceController;
  final ExecutableScanner executableScanner;
  final InstalledAppsScanner installedAppsScanner;

  @override
  State<_AddCustomBlockDialog> createState() =>
      _AddCustomBlockDialogState();
}

class _AddCustomBlockDialogState extends State<_AddCustomBlockDialog> {
  late Future<List<ServiceInfo>> _servicesFuture;
  late Future<List<InstalledApp>> _appsFuture;
  final Set<String> _selected = <String>{};
  final Set<String> _selectedPrograms = <String>{};
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _servicesFuture = widget.serviceController.findServicesByPattern(
      nameContains: 'update',
      displayContains: 'update',
    );
    _appsFuture = widget.installedAppsScanner.scan();
    _titleController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      (_selected.isNotEmpty || _selectedPrograms.isNotEmpty) &&
      _titleController.text.trim().isNotEmpty;

  void _toggleSelection(String serviceName) {
    setState(() {
      if (_selected.contains(serviceName)) {
        _selected.remove(serviceName);
      } else {
        _selected.add(serviceName);
      }
    });
  }

  void _toggleProgram(String path) {
    setState(() {
      if (_selectedPrograms.contains(path)) {
        _selectedPrograms.remove(path);
      } else {
        _selectedPrograms.add(path);
      }
    });
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.pop(
      context,
        _CustomBlockRequest(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? AppLocalizations.of(context).text(
                  'updaterCustomBlockDefault',
                  'Custom firewall block created from Updater.',
                )
              : _descriptionController.text.trim(),
          serviceNames: _selected.toList(),
          programPaths: _selectedPrograms.toList(),
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    String tr(String key, String fallback) => t.text(key, fallback);
    return ContentDialog(
      title: Text(tr('updaterCustomDialogTitle', 'Add custom updater block')),
      content: SizedBox(
        width: 720,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('generalTitle', 'Title')),
            const SizedBox(height: 4),
            TextBox(
              controller: _titleController,
              placeholder: tr('updaterTitlePlaceholder', 'e.g., Block Foo Updater'),
            ),
            const SizedBox(height: 12),
            Text(tr('generalDescriptionOptional', 'Description (optional)')),
            const SizedBox(height: 4),
            TextBox(
              controller: _descriptionController,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabView(
                currentIndex: _tabIndex,
                onChanged: (index) {
                  setState(() {
                    _tabIndex = index;
                  });
                },
                closeButtonVisibility: CloseButtonVisibilityMode.never,
                tabs: [
                  Tab(
                    text: Text(tr('updaterInstalledAppsTab', 'Installed apps')),
                    body: _InstalledAppsTab(
                      future: _appsFuture,
                      selectedPaths: _selectedPrograms,
                      onToggle: _toggleProgram,
                    ),
                  ),
                  Tab(
                    text: Text(tr('updaterServicesTab', 'Services')),
                    body: _ServicesTab(
                      servicesFuture: _servicesFuture,
                      selected: _selected,
                      onToggle: _toggleSelection,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('generalCancel', 'Cancel')),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(tr('generalCreate', 'Create')),
        ),
      ],
    );
  }
}

class _ServicesTab extends StatefulWidget {
  const _ServicesTab({
    required this.servicesFuture,
    required this.selected,
    required this.onToggle,
  });

  final Future<List<ServiceInfo>> servicesFuture;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  State<_ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<_ServicesTab> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    String tr(String key, String fallback) => t.text(key, fallback);
    return FutureBuilder<List<ServiceInfo>>(
      future: widget.servicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: ProgressRing());
        }
        if (snapshot.hasError) {
          return Text(
            '${tr('updaterServicesLoadFailed', 'Failed to enumerate services')}: ${snapshot.error}',
          );
        }
        final services = List<ServiceInfo>.of(
          snapshot.data ?? const <ServiceInfo>[],
        );
        if (services.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              tr(
                'updaterNoServicesFound',
                'No update-related services detected. You can still add rules manually later.',
              ),
            ),
          );
        }
        services.sort(
          (a, b) =>
              a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
        );
        return RawScrollbar(
          controller: _controller,
          thumbVisibility: true,
          child: _SelectableListView<ServiceInfo>(
            items: services,
            controller: _controller,
            isChecked: (service) => widget.selected.contains(service.name),
            onToggle: (service) => widget.onToggle(service.name),
            titleBuilder: (service) => service.displayName.isEmpty
                ? service.name
                : service.displayName,
            subtitleBuilder: (service) =>
                service.displayName.isEmpty ? null : service.name,
          ),
        );
      },
    );
  }
}

class _InstalledAppsTab extends StatefulWidget {
  const _InstalledAppsTab({
    required this.future,
    required this.selectedPaths,
    required this.onToggle,
  });

  final Future<List<InstalledApp>> future;
  final Set<String> selectedPaths;
  final ValueChanged<String> onToggle;

  @override
  State<_InstalledAppsTab> createState() => _InstalledAppsTabState();
}

class _InstalledAppsTabState extends State<_InstalledAppsTab> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    String tr(String key, String fallback) => t.text(key, fallback);
    return FutureBuilder<List<InstalledApp>>(
      future: widget.future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: ProgressRing());
        }
        if (snapshot.hasError) {
          return Text(
            '${tr('updaterAppsLoadFailed', 'Failed to scan installed apps')}: ${snapshot.error}',
          );
        }
        final apps = snapshot.data ?? const <InstalledApp>[];
        if (apps.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              tr(
                'updaterNoAppsFound',
                'No installed apps with updater executables found.',
              ),
            ),
          );
        }
        final sorted = List<InstalledApp>.of(apps)
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
        return RawScrollbar(
          controller: _controller,
          thumbVisibility: true,
          child: ListView.builder(
            controller: _controller,
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final app = sorted[index];
              return Expander(
                header: Text(app.name),
                content: _SelectableListView<ExecutableCandidate>(
                  items: app.executables,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  isChecked: (exe) =>
                      widget.selectedPaths.contains(exe.path),
                  onToggle: (exe) => widget.onToggle(exe.path),
                  titleBuilder: (exe) => exe.displayName,
                  subtitleBuilder: (exe) => exe.path,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SelectableListView<T> extends StatelessWidget {
  const _SelectableListView({
    required this.items,
    required this.isChecked,
    required this.onToggle,
    required this.titleBuilder,
    this.subtitleBuilder,
    this.controller,
    this.shrinkWrap = false,
    this.physics,
  });

  final List<T> items;
  final bool Function(T item) isChecked;
  final ValueChanged<T> onToggle;
  final String Function(T item) titleBuilder;
  final String? Function(T item)? subtitleBuilder;
  final ScrollController? controller;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final checked = isChecked(item);
        final subtitle = subtitleBuilder?.call(item);
        return ListTile.selectable(
          selected: checked,
          onPressed: () => onToggle(item),
          leading: Checkbox(
            checked: checked,
            onChanged: (_) => onToggle(item),
          ),
          title: Text(titleBuilder(item)),
          subtitle: subtitle == null ? null : Text(subtitle),
        );
      },
    );
  }
}
