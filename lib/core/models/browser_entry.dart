class BrowserEntry {
  const BrowserEntry({
    required this.id,
    required this.label,
    required this.profileCount,
    this.executablePath,
  });

  final String id;
  final String label;
  final int profileCount;
  final String? executablePath;
}
