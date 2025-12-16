import '../localization/app_localizations.dart';
import '../models/tool_definition.dart';

extension ToolDefinitionLocalization on ToolDefinition {
  String localizedTitle(AppLocalizations t) {
    final languageCode = t.locale.languageCode;
    return _resolvedValue(localizedTitles, languageCode, title);
  }

  String localizedDescription(AppLocalizations t) {
    final languageCode = t.locale.languageCode;
    return _resolvedValue(localizedDescriptions, languageCode, description);
  }

  String _resolvedValue(
    Map<String, String> values,
    String languageCode,
    String fallback,
  ) {
    if (values.isEmpty) return fallback;
    return values[languageCode] ??
        values['en'] ??
        fallback;
  }
}
