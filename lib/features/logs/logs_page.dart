import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/providers.dart';

class LogsPage extends ConsumerWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final entries = ref.watch(logsControllerProvider);
    final statusMessage = ref.watch(_logsStatusProvider);
    final isCleaning = ref.watch(_logsCleaningProvider);

    return ScaffoldPage(
      header: PageHeader(
        title: Text(t.pageLogsTitle),
        commandBar: CommandBar(
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.delete),
              label: Text(
                isCleaning
                    ? t.text('logsDeleting', 'Deleting...')
                    : t.text('logsClearAll', 'Clear all entries'),
              ),
              onPressed: isCleaning
                  ? null
                  : () async {
                      ref.read(_logsCleaningProvider.notifier).state = true;
                      await ref
                          .read(logsControllerProvider.notifier)
                          .clearAll();
                      ref.read(_logsStatusProvider.notifier).state =
                          t.text('logsClearedMessage', 'All log entries removed.');
                      ref.read(_logsCleaningProvider.notifier).state = false;
                    },
            ),
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InfoBar(
                  severity: InfoBarSeverity.info,
                  title: Text(t.text('logsCleanupTitle', 'Cleanup')),
                  content: Text(statusMessage),
                  action: IconButton(
                    icon: const Icon(FluentIcons.clear),
                    onPressed: () =>
                        ref.read(_logsStatusProvider.notifier).state = null,
                  ),
                ),
              ),
            Expanded(
              child: entries.isEmpty
                  ? Center(child: Text(t.text('logsEmpty', 'No recorded runs yet.')))
                  : ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(entry.toolTitle),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.startedAt} | ${entry.status} | ${entry.durationMs}ms',
                                ),
                                if (entry.actionSummary != null)
                                  Text(
                                    '${t.text('logsActions', 'Actions')}: ${entry.actionSummary}',
                                  ),
                                if (entry.backupPath != null)
                                  Text(
                                    '${t.text('logsBackup', 'Backup')}: ${entry.backupPath}',
                                  ),
                                if (entry.errorCode != null)
                                  Text(
                                    '${t.text('generalErrorCode', 'Error code')}: ${entry.errorCode}',
                                  ),
                              ],
                            ),
                            trailing: _LogStatusChip(
                              icon: entry.status == 'success'
                                  ? FluentIcons.check_mark
                                  : FluentIcons.warning,
                              text: entry.status.toUpperCase(),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

final _logsStatusProvider = StateProvider<String?>((ref) => null);
final _logsCleaningProvider = StateProvider<bool>((ref) => false);

class _LogStatusChip extends StatelessWidget {
  const _LogStatusChip({
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
