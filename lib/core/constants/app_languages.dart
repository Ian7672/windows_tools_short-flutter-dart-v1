class AppLanguage {
  const AppLanguage({required this.code, required this.label});

  final String code;
  final String label;
}

const List<AppLanguage> kSupportedLanguages = [
  AppLanguage(code: 'en', label: 'English'),
  AppLanguage(code: 'id', label: 'Bahasa Indonesia'),
  AppLanguage(code: 'zh', label: '中文 (China)'),
  AppLanguage(code: 'ja', label: '日本語 (Japanese)'),
  AppLanguage(code: 'ko', label: '한국어 (Korean)'),
  AppLanguage(code: 'ar', label: 'العربية (Arabic)'),
  AppLanguage(code: 'ru', label: 'Русский (Russian)'),
  AppLanguage(code: 'hi', label: 'Hindi (India)'),
];
