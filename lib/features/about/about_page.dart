import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/providers.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    String tr(String key, String fallback) => t.text(key, fallback);
    final info = ref.watch(packageInfoProvider);
    final donationLinks = [
      (
        label: tr('aboutDonateTrakteer', 'Trakteer'),
        url: 'https://trakteer.id/Ian7672',
      ),
      (
        label: tr('aboutDonateKofi', 'Ko-fi'),
        url: 'https://ko-fi.com/Ian7672',
      ),
    ];

    return ScaffoldPage(
      header: PageHeader(title: Text(t.pageAboutTitle)),
      content: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info.appName,
              style: FluentTheme.of(context).typography.title,
            ),
            Text('${tr('aboutVersion', 'Version')} ${info.version}+${info.buildNumber}'),
            const SizedBox(height: 12),
            Text(
              tr(
                'aboutDescription',
                'Ian7672 Windows Toolkit centralises native maintenance actions for keeping Xbox Gaming Services and Windows update components under your control.',
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('aboutCredits', 'Credits'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                        'aboutCreditIan',
                        'github: Ian7672 – original Gaming Services blocking script.',
                      ),
                    ),
                    Text(
                      tr('aboutCreditIan7672', 'Ian7672 – app integration & packaging.'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('aboutSupportTitle', 'Support the project'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                        'aboutSupportDescription',
                        'If this toolkit helps you, consider buying the creator a coffee.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: donationLinks
                          .map(
                            (entry) => HyperlinkButton(
                              onPressed: () => _launchExternal(entry.url),
                              child: Text(entry.label),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _launchExternal(String url) async {
  await launchUrlString(
    url,
    mode: LaunchMode.externalApplication,
  );
}
