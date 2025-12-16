import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/providers.dart';
import '../../router.dart';

class NavigationItemData {
  const NavigationItemData({
    required this.titleKey,
    required this.icon,
    required this.route,
  });

  final String titleKey;
  final IconData icon;
  final String route;
}

const _navItems = <NavigationItemData>[
  NavigationItemData(
    titleKey: 'dashboard',
    icon: FluentIcons.home,
    route: RoutePaths.dashboard,
  ),
  NavigationItemData(
    titleKey: 'updater',
    icon: FluentIcons.sync,
    route: RoutePaths.updater,
  ),
  NavigationItemData(
    titleKey: 'cleaner',
    icon: FluentIcons.brush,
    route: RoutePaths.cleaner,
  ),
  NavigationItemData(
    titleKey: 'other',
    icon: FluentIcons.developer_tools,
    route: RoutePaths.other,
  ),
  NavigationItemData(
    titleKey: 'logs',
    icon: FluentIcons.activity_feed,
    route: RoutePaths.logs,
  ),
  NavigationItemData(
    titleKey: 'settings',
    icon: FluentIcons.settings,
    route: RoutePaths.settings,
  ),
  NavigationItemData(
    titleKey: 'about',
    icon: FluentIcons.info,
    route: RoutePaths.about,
  ),
];

class SideNavigationShell extends ConsumerWidget {
  const SideNavigationShell({
    super.key,
    required this.state,
    required this.child,
  });

  final GoRouterState state;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final currentRoute = state.uri.toString();
    final selectedIndex = _navItems.indexWhere(
      (item) => currentRoute.startsWith(item.route),
    );
    final adminState = ref.watch(adminStatusProvider);
    final controller = ref.read(adminStatusProvider.notifier);
    final showAdminBanner = adminState.maybeWhen(
      data: (value) => !value,
      orElse: () => false,
    );

    return NavigationView(
      paneBodyBuilder: (item, body) {
        return Column(
          children: [
            if (showAdminBanner)
              Padding(
                padding: const EdgeInsets.all(8),
                child: InfoBar(
                  severity: InfoBarSeverity.warning,
                  title: Text(t.adminBannerTitle),
                  content: Text(t.adminBannerMessage),
                  action: Button(
                    onPressed: () {
                      controller.requestElevation().then((launched) {
                        if (!context.mounted || launched) {
                          return;
                        }
                        displayInfoBar(
                          context,
                          builder: (context, close) => InfoBar(
                            severity: InfoBarSeverity.error,
                            title: Text(t.adminBannerDismissedTitle),
                            content: Text(
                              t.adminBannerDismissedMessage,
                            ),
                          ),
                        );
                      });
                    },
                    child: Text(t.adminBannerAction),
                  ),
                ),
              ),
            if (adminState.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: InfoBar(
                  severity: InfoBarSeverity.error,
                  title: Text(t.adminCheckFailedTitle),
                  content: Text(adminState.error.toString()),
                  action: Button(
                    onPressed: controller.recheck,
                    child: Text(t.retryLabel),
                  ),
                ),
              ),
            Expanded(child: child),
          ],
        );
      },
      pane: NavigationPane(
        selected: selectedIndex < 0 ? 0 : selectedIndex,
        onChanged: (index) {
          if (index < 0 || index >= _navItems.length) return;
          final target = _navItems[index];
          if (target.route != currentRoute) {
            context.go(target.route);
          }
        },
        items: _navItems
            .map<NavigationPaneItem>(
              (item) => PaneItem(
                icon: Icon(item.icon),
                title: Text(_navTitle(t, item.titleKey)),
                body: const SizedBox.shrink(),
              ),
            )
            .toList(),
      ),
    );
  }
}

String _navTitle(AppLocalizations t, String key) {
  switch (key) {
    case 'dashboard':
      return t.navDashboard;
    case 'updater':
      return t.navUpdater;
    case 'cleaner':
      return t.navCleaner;
    case 'other':
      return t.navOther;
    case 'logs':
      return t.navLogs;
    case 'settings':
      return t.navSettings;
    case 'about':
      return t.navAbout;
    default:
      return key;
  }
}
