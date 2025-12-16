import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/tool_localizations.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/tool_definition.dart';
import '../../core/providers.dart';
import '../../router.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    String tr(String key, String fallback) => t.text(key, fallback);
    final manifestState = ref.watch(toolsManifestControllerProvider);

    return ScaffoldPage(
      header: PageHeader(title: Text(t.pageDashboardTitle)),
      content: manifestState.when(
        data: (manifest) {
          final updaterTools =
              manifest.tools.where((tool) => tool.category == 'updater').toList();
          final otherTools =
              manifest.tools.where((tool) => tool.category == 'other').toList();

          final cards = <_DashboardCardData>[
            _DashboardCardData(
              title: t.navUpdater,
              description: tr('dashboardUpdaterDesc',
                  'Native Windows/Xbox services, firewall, and policy toggles.'),
              icon: FluentIcons.cloud_download,
              route: RoutePaths.updater,
              highlights: _highlightTools(updaterTools, t),
            ),
            _DashboardCardData(
              title: t.navCleaner,
              description:
                  tr('dashboardCleanerDesc', 'Startup optimizer and junk/cache cleanup suite.'),
              icon: FluentIcons.broom,
              route: RoutePaths.cleaner,
              highlights: [
                tr('cleanerPerformanceHighlight', 'Performance Cleaner'),
                tr('cleanerJunkHighlight', 'Junk Cleaner'),
              ],
            ),
            _DashboardCardData(
              title: t.navOther,
              description: tr('dashboardOtherDesc', 'Sandbox for future tooling experiments.'),
              icon: FluentIcons.lightbulb,
              route: RoutePaths.other,
              highlights: _highlightTools(otherTools, t),
            ),
            _DashboardCardData(
              title: t.navLogs,
              description:
                  tr('dashboardLogsDesc', 'See previous runs, backups, and retention status.'),
              icon: FluentIcons.activity_feed,
              route: RoutePaths.logs,
              highlights: [
                tr('dashboardHistoryHighlight', 'History'),
                tr('dashboardBackupsHighlight', 'Backups'),
              ],
            ),
            _DashboardCardData(
              title: t.navSettings,
              description: tr(
                'dashboardSettingsDesc',
                'Preferences, confirmations, theme, and script import.',
              ),
              icon: FluentIcons.settings,
              route: RoutePaths.settings,
              highlights: [
                tr('dashboardHighRiskHighlight', 'High-risk toggle'),
                tr('dashboardThemeHighlight', 'Dark/Light mode'),
              ],
            ),
            _DashboardCardData(
              title: t.navAbout,
              description:
                  tr('dashboardAboutDesc', 'Version info and credit: github.com/Ian7672.'),
              icon: FluentIcons.info,
              route: RoutePaths.about,
              highlights: [tr('dashboardReleaseHighlight', 'Release info')],
            ),
          ];

          return LayoutBuilder(
            builder: (context, constraints) {
              const targetCardWidth = 280.0;
              final availableWidth =
                  constraints.hasBoundedWidth && constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : targetCardWidth * 3;
              final columns = (availableWidth / (targetCardWidth + 16))
                  .floor()
                  .clamp(1, 4);
              final usableWidth =
                  availableWidth - ((columns - 1) * 16).clamp(0, availableWidth);
              final cardWidth = usableWidth / columns;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: cards
                              .map<Widget>(
                                (data) => ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: targetCardWidth,
                                    maxWidth: cardWidth,
                                  ),
                                  child: _DashboardCard(
                                    data: data,
                                    onTap: () => context.go(data.route),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
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
    );
  }

  List<String> _highlightTools(
    List<ToolDefinition> tools,
    AppLocalizations t,
  ) {
    if (tools.isEmpty) {
      return const [];
    }
    return tools
        .map((tool) => tool.localizedTitle(t))
        .take(3)
        .toList();
  }
}

class _DashboardCardData {
  const _DashboardCardData({
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
    required this.highlights,
  });

  final String title;
  final String description;
  final IconData icon;
  final String route;
  final List<String> highlights;
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.data,
    required this.onTap,
  });

  final _DashboardCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                data.icon,
                size: 32,
                color: theme.accentColor,
              ),
              const SizedBox(height: 12),
              Text(
                data.title,
                style: theme.typography.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                data.description,
                style: theme.typography.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (data.highlights.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: data.highlights
                      .map<Widget>(
                        (highlight) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.resources.controlStrokeColorDefault,
                            ),
                          ),
                          child: Text(
                            highlight,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.caption,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
