import 'package:fluent_ui/fluent_ui.dart';

import '../../core/localization/app_localizations.dart';

class OtherToolsPage extends StatelessWidget {
  const OtherToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ScaffoldPage(
      header: PageHeader(title: Text(t.pageOtherTitle)),
      content: Center(
        child: Text(
          AppLocalizations.of(context).text(
            'otherPlaceholder',
            'Reserved for future diagnostics and utilities.\nAdd entries to tools_manifest.json to surface them here.',
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
