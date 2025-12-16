import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/about/about_page.dart';
import 'features/cleaner/cleaner_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/logs/logs_page.dart';
import 'features/other/other_page.dart';
import 'features/settings/settings_page.dart';
import 'features/updater/updater_page.dart';
import 'shared/widgets/navigation_shell.dart';

class RoutePaths {
  static const dashboard = '/dashboard';
  static const updater = '/updater';
  static const cleaner = '/cleaner';
  static const other = '/other';
  static const logs = '/logs';
  static const settings = '/settings';
  static const about = '/about';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RoutePaths.dashboard,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            SideNavigationShell(state: state, child: child),
        routes: [
          GoRoute(
            path: RoutePaths.dashboard,
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: RoutePaths.updater,
            builder: (context, state) => const UpdaterPage(),
          ),
          GoRoute(
            path: RoutePaths.cleaner,
            builder: (context, state) => const CleanerPage(),
          ),
          GoRoute(
            path: RoutePaths.other,
            builder: (context, state) => const OtherToolsPage(),
          ),
          GoRoute(
            path: RoutePaths.logs,
            builder: (context, state) => const LogsPage(),
          ),
          GoRoute(
            path: RoutePaths.settings,
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: RoutePaths.about,
            builder: (context, state) => const AboutPage(),
          ),
        ],
      ),
    ],
  );
});
