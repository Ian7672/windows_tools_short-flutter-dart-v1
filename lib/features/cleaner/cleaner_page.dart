import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material show ScrollController, RawScrollbar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/localization/app_localizations.dart';
import '../../core/models/startup_item.dart';
import '../../core/providers.dart';
import 'cleaner_controller.dart';

const _categoryRecycleBin = 'recycle_bin';
const _categoryWindowsUpdate = 'cleanWindowsUpdate';
const _categoryTempInstall = 'cleanTemporaryInstall';
const _categoryDriverPackages = 'cleanDriverPackages';
const _categoryPreviousWindows = 'cleanPreviousInstalls';
const _categoryDisableHibernation = 'disableHibernation';
const _categoryComponentCleanup = 'componentCleanup';
const _categoryBrowserPrefix = 'browser_';

class CleanerPage extends ConsumerStatefulWidget {
  const CleanerPage({super.key});

  @override
  ConsumerState<CleanerPage> createState() => _CleanerPageState();
}

class _CleanerPageState extends ConsumerState<CleanerPage> {
  final material.ScrollController _scrollController =
      material.ScrollController();

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 MB';
    final gb = bytes / (1024 * 1024 * 1024);
    if (gb >= 1) {
      return '${gb.toStringAsFixed(2)} GB';
    }
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }

  String _categorySizeText(
    AppLocalizations loc,
    JunkCleanerState state,
    String categoryId,
  ) {
    final scan = state.scanResult;
    if (scan == null) {
      return loc.text('cleanerScanToEstimate', ' (scan to estimate)');
    }
    final size = scan.sizeForCategory(categoryId);
    return ' (${_formatSize(size)})';
  }

  int _selectedCleanupSize(JunkCleanerState state) {
    final scan = state.scanResult;
    if (scan == null) return 0;
    var total = scan.totalSizeBytes;
    if (state.includeRecycleBin) {
      total += scan.sizeForCategory(_categoryRecycleBin);
    }
    if (state.cleanWindowsUpdate) {
      total += scan.sizeForCategory(_categoryWindowsUpdate);
    }
    if (state.cleanTemporaryInstall) {
      total += scan.sizeForCategory(_categoryTempInstall);
    }
    if (state.cleanDriverPackages) {
      total += scan.sizeForCategory(_categoryDriverPackages);
    }
    if (state.cleanPreviousInstalls) {
      total += scan.sizeForCategory(_categoryPreviousWindows);
    }
    if (state.disableHibernation) {
      total += scan.sizeForCategory(_categoryDisableHibernation);
    }
    if (state.runComponentCleanup) {
      total += scan.sizeForCategory(_categoryComponentCleanup);
    }
    for (final id in state.selectedBrowserIds) {
      total += scan.sizeForCategory('$_categoryBrowserPrefix$id');
    }
    return total;
  }

  String _browserSizeLabel(
    AppLocalizations loc,
    JunkCleanerState state,
    String browserId,
  ) {
    final scan = state.scanResult;
    if (scan == null) {
      return loc.text('cleanerScanToEstimate', ' (scan to estimate)');
    }
    final size = scan.sizeForCategory('$_categoryBrowserPrefix$browserId');
    return ' (${_formatSize(size)})';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    String tr(String key, String fallback) => t.text(key, fallback);
    final startupState = ref.watch(startupCleanerControllerProvider);
    final startupController =
        ref.read(startupCleanerControllerProvider.notifier);
    final junkState = ref.watch(junkCleanerControllerProvider);
    final junkController = ref.read(junkCleanerControllerProvider.notifier);

    return ScaffoldPage(
      header: PageHeader(title: Text(t.pageCleanerTitle)),
      content: Padding(
        padding: const EdgeInsets.all(16),
        child: material.RawScrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          interactive: true,
          thickness: 14,
          radius: const Radius.circular(12),
          thumbColor: FluentTheme.of(context)
              .accentColor
              .withValues(alpha: 0.8),
          child: ListView(
        controller: _scrollController,
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('cleanerPerformanceTitle', 'Performance Cleaner (Startup Manager)'),
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      'cleanerPerformanceSubtitle',
                      'Disable every startup item except the trusted allowlist. Backup is created before modifications.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Button(
                        onPressed: startupState.isLoading
                            ? null
                            : () => startupController.loadItems(),
                        child: Text(tr('cleanerRefreshList', 'Refresh list')),
                      ),
                      FilledButton(
                        onPressed: startupState.isLoading
                            ? null
                            : () => startupController
                                .disableAllExceptAllowlist(),
                        child: Text(
                          tr('cleanerDisableNonAllowlisted', 'Disable non-allowlisted'),
                        ),
                      ),
                      Button(
                        onPressed: startupState.isLoading
                            ? null
                            : () => startupController.restoreBackup(),
                        child: Text(tr('cleanerRestoreBackup', 'Restore from backup')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (startupState.message != null)
                    InfoBar(
                      severity: InfoBarSeverity.info,
                      title: Text(tr('generalStatus', 'Status')),
                      content: Text(startupState.message!),
                    ),
                  const SizedBox(height: 8),
                  startupState.isLoading
                      ? const SizedBox(
                          height: 120,
                          child: Center(child: ProgressRing()),
                        )
                      : _StartupTable(items: startupState.items),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr('cleanerJunkTitle', 'Junk / Cache Cleaner'),
                        style: FluentTheme.of(context).typography.subtitle,
                      ),
                      Tooltip(
                        message: tr('cleanerScanBrowsers', 'Scan installed browsers'),
                        child: IconButton(
                          icon: const Icon(FluentIcons.refresh),
                          onPressed: () => junkController.detectBrowsers(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ToggleSwitch(
                    checked: junkState.includeRecycleBin,
                    onChanged: junkController.toggleRecycleBin,
                    content: Text(
                      tr(
                            'cleanerIncludeRecycle',
                            'Include Recycle Bin (requires confirmation)',
                          ) +
                          _categorySizeText(t, junkState, _categoryRecycleBin),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('cleanerDiskCleanupTitle', 'Disk Cleanup (system files)'),
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Checkbox(
                        checked: junkState.cleanWindowsUpdate,
                        onChanged: (value) => junkController.updateOptions(
                          cleanWindowsUpdate: value ?? false,
                        ),
                        content: Text(
                          tr('cleanerWindowsUpdateCleanup', 'Windows Update Cleanup') +
                              _categorySizeText(t, junkState, _categoryWindowsUpdate),
                        ),
                      ),
                      Checkbox(
                        checked: junkState.cleanTemporaryInstall,
                        onChanged: (value) => junkController.updateOptions(
                          cleanTemporaryInstall: value ?? false,
                        ),
                        content: Text(
                          tr('cleanerTemporaryInstall', 'Temporary installation files') +
                              _categorySizeText(t, junkState, _categoryTempInstall),
                        ),
                      ),
                      Checkbox(
                        checked: junkState.cleanDriverPackages,
                        onChanged: (value) => junkController.updateOptions(
                          cleanDriverPackages: value ?? false,
                        ),
                        content: Text(
                          tr('cleanerDriverPackages', 'Device driver packages') +
                              _categorySizeText(t, junkState, _categoryDriverPackages),
                        ),
                      ),
                      Checkbox(
                        checked: junkState.cleanPreviousInstalls,
                        onChanged: (value) => junkController.updateOptions(
                          cleanPreviousInstalls: value ?? false,
                        ),
                        content: Text(
                          tr(
                                'cleanerPreviousWindows',
                                'Previous Windows installation (windows.old)',
                              ) +
                              _categorySizeText(t, junkState, _categoryPreviousWindows),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(
                      'cleanerPreviousWindowsNote',
                      'Note: removing windows.old prevents rolling back to the previous Windows version.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PathInfoExpander(
                    title: tr('cleanerDiskLocations', 'Disk cleanup locations'),
                    entries: _diskCleanupPaths,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('cleanerAdvancedActions', 'Advanced actions'),
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Checkbox(
                        checked: junkState.disableHibernation,
                        onChanged: (value) => junkController.updateOptions(
                          disableHibernation: value ?? false,
                        ),
                        content: Text(
                          tr(
                                'cleanerDisableHibernation',
                                'Disable hibernation (removes hiberfil.sys)',
                              ) +
                              _categorySizeText(t, junkState, _categoryDisableHibernation),
                        ),
                      ),
                      Checkbox(
                        checked: junkState.runComponentCleanup,
                        onChanged: (value) => junkController.updateOptions(
                          runComponentCleanup: value ?? false,
                        ),
                        content: Text(
                          tr(
                                'cleanerComponentCleanup',
                                'Component store cleanup (WinSxS temp)',
                              ) +
                              _categorySizeText(t, junkState, _categoryComponentCleanup),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _PathInfoExpander(
                    title: tr('cleanerAdvancedLocations', 'Advanced action paths'),
                    entries: _advancedCleanupPaths,
                  ),
                  const SizedBox(height: 4),
                  Button(
                    onPressed: junkState.isHibernationBusy
                        ? null
                        : () => junkController.enableHibernation(),
                    child: junkState.isHibernationBusy
                        ? Text(tr('cleanerEnablingHibernation', 'Enabling hibernation...'))
                        : Text(
                            tr(
                              'cleanerEnableHibernation',
                              'Re-enable hibernation (powercfg -h on)',
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('cleanerBrowserCache', 'Browser cache'),
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  const SizedBox(height: 4),
                  if (junkState.detectedBrowsers.isEmpty)
                    InfoBar(
                      severity: InfoBarSeverity.warning,
                      title: Text(tr('cleanerNoBrowsers', 'No browsers detected')),
                      content: Text(
                        tr(
                          'cleanerRefreshBrowsersHint',
                          'Use the refresh icon above after installing browsers.',
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: junkState.detectedBrowsers
                          .map(
                            (browser) => Checkbox(
                              checked: junkController.isBrowserSelected(browser),
                              onChanged: (value) =>
                                  junkController.toggleBrowser(
                                browser,
                                value ?? false,
                              ),
                              content: Text(
                                '${browser.label}'
                                '${_browserSizeLabel(t, junkState, browser.id)}',
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 8),
                  _PathInfoExpander(
                    title: tr('cleanerBrowserCachePaths', 'Browser cache locations'),
                    entries: _browserCachePaths,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      Button(
                        onPressed: junkState.isScanning
                            ? null
                            : () => junkController.scan(),
                        child: Text(tr('cleanerDryRun', 'Dry-run scan')),
                      ),
                      FilledButton(
                        onPressed: junkState.isCleaning
                                ? null
                                : () => junkController.clean(),
                        child: Text(tr('cleanerCleanSelected', 'Clean selected locations')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (junkState.message != null)
                    InfoBar(
                      severity: InfoBarSeverity.info,
                      title: Text(tr('generalStatus', 'Status')),
                      content: Text(junkState.message!),
                    ),
                  if (junkState.scanResult != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${tr('cleanerEstimatedCleanup', 'Estimated selected cleanup')}: '
                          '${_formatSize(_selectedCleanupSize(junkState))}',
                          style: FluentTheme.of(context).typography.caption,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  _JunkSummary(state: junkState),
                ],
              ),
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

const Map<String, List<String>> _diskCleanupPaths = {
  'Windows Update Cleanup': [
    r'%WINDIR%\SoftwareDistribution\Download',
    r'%WINDIR%\SoftwareDistribution\DataStore\Logs',
    r'%WINDIR%\SoftwareDistribution\DeliveryOptimization\Cache',
  ],
  'Temporary installation files': [
    r'%SYSTEMDRIVE%\$WINDOWS.~BT',
    r'%SYSTEMDRIVE%\$WINDOWS.~WS',
    r'%WINDIR%\Panther',
  ],
  'Device driver packages': [
    r'%WINDIR%\System32\DriverStore\FileRepository (tmp folders)',
  ],
  'Previous Windows installation (windows.old)': [
    r'%SYSTEMDRIVE%\Windows.old',
  ],
};

const Map<String, List<String>> _advancedCleanupPaths = {
  'Disable hibernation': [
    r'%SYSTEMDRIVE%\hiberfil.sys',
    r'HKLM\SYSTEM\CurrentControlSet\Control\Power (HibernateEnabled)',
  ],
  'Component store cleanup': [
    r'%WINDIR%\WinSxS\Temp',
    r'%WINDIR%\WinSxS\ManifestCache',
    r'%WINDIR%\servicing\LCU',
  ],
};

const Map<String, List<String>> _browserCachePaths = {
  'Chrome': [r'%LOCALAPPDATA%\Google\Chrome\User Data\*'],
  'Edge': [r'%LOCALAPPDATA%\Microsoft\Edge\User Data\*'],
  'Firefox': [r'%APPDATA%\Mozilla\Firefox\Profiles\*\cache2'],
  'Brave': [r'%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\*'],
  'Opera': [r'%LOCALAPPDATA%\Opera Software\Opera Stable\Cache'],
  'Opera GX': [r'%LOCALAPPDATA%\Opera Software\Opera GX Stable\Cache'],
  'Vivaldi': [r'%LOCALAPPDATA%\Vivaldi\User Data\*'],
  'Yandex': [r'%LOCALAPPDATA%\Yandex\YandexBrowser\User Data\*'],
};

class _StartupTable extends StatelessWidget {
  const _StartupTable({required this.items});

  final List<StartupItem> items;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    String tr(String key, String fallback) => t.text(key, fallback);
    if (items.isEmpty) {
      return Center(
        child: Text(tr('cleanerNoStartupItems', 'No startup items detected.')),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          title: Text(item.name),
          subtitle: Text(item.command),
          leading: Icon(
            item.allowlisted
                ? FluentIcons.shield
                : FluentIcons.block_contact,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StartupStatusChip(
                enabled: item.enabled,
              ),
              const SizedBox(height: 6),
              Text(item.source.label),
            ],
          ),
        );
      },
    );
  }
}

class _StartupStatusChip extends StatelessWidget {
  const _StartupStatusChip({required this.enabled});

  final bool enabled;

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
          Icon(
            enabled ? FluentIcons.check_mark : FluentIcons.block_contact,
            size: 12,
          ),
          const SizedBox(width: 6),
          Text(
            AppLocalizations.of(context).text(
              enabled ? 'cleanerStatusEnabled' : 'cleanerStatusDisabled',
              enabled ? 'ENABLED' : 'DISABLED',
            ),
            style: theme.typography.caption,
          ),
        ],
      ),
    );
  }
}

class _JunkSummary extends StatelessWidget {
  const _JunkSummary({required this.state});

  final JunkCleanerState state;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    String tr(String key, String fallback) => t.text(key, fallback);
    final result = state.scanResult;
    final theme = FluentTheme.of(context);
    if (state.isScanning) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: ProgressRing()),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: state.currentScanPath == null
                ? const SizedBox.shrink()
                : Text(
                    '${tr('cleanerScanning', 'Scanning')}: ${state.currentScanPath}',
                    key: ValueKey(state.currentScanPath),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption,
                  ),
          ),
        ],
      );
    }
    if (result == null) {
      return Text(tr('cleanerRunScanHint', 'Run a dry-run scan to see estimations.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${tr('cleanerTotalSize', 'Total size')}: ${(result.totalSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
        ),
        Text('${tr('cleanerTotalFiles', 'Total files')}: ${result.totalFiles}'),
        const SizedBox(height: 8),
        ...result.entries.map((entry) {
          final sizeMb =
              (entry.sizeBytes / (1024 * 1024)).toStringAsFixed(2);
          final displayName = entry.label ??
              (p.basename(entry.path).isEmpty
                  ? entry.path
                  : p.basename(entry.path));
          final title = '$displayName - $sizeMb MB';
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Expander(
              initiallyExpanded: false,
              header: Text(title),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(entry.path),
                  Text(
                    "${tr('cleanerEntryFiles', 'Files')}: ${entry.fileCount}",
                  ),
                  if (entry.errors.isNotEmpty) ...[
                    SizedBox(height: 4),
                    ...entry.errors.map(
                      (err) => Text(
                        "${tr('cleanerEntryError', 'Error')}: $err",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _PathInfoExpander extends StatelessWidget {
  const _PathInfoExpander({
    required this.title,
    required this.entries,
  });

  final String title;
  final Map<String, List<String>> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final theme = FluentTheme.of(context);
    return Expander(
      initiallyExpanded: false,
      header: Text(title),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: theme.typography.caption?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                ...entry.value.map(
                  (path) => SelectableText(
                    path,
                    style: theme.typography.caption,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
