class JunkEntry {
  JunkEntry({
    required this.path,
    required this.sizeBytes,
    required this.fileCount,
    this.label,
    List<String>? errors,
  }) : errors = errors ?? <String>[];

  final String path;
  final int sizeBytes;
  final int fileCount;
  final String? label;
  final List<String> errors;
}

class JunkCategoryInfo {
  const JunkCategoryInfo({
    required this.id,
    required this.label,
    required this.sizeBytes,
    required this.fileCount,
    List<String>? paths,
    List<String>? errors,
  })  : paths = paths ?? const <String>[],
        errors = errors ?? const <String>[];

  final String id;
  final String label;
  final int sizeBytes;
  final int fileCount;
  final List<String> paths;
  final List<String> errors;
}

class JunkScanResult {
  const JunkScanResult({
    required this.entries,
    required this.scannedAt,
    required this.categories,
  });

  final List<JunkEntry> entries;
  final DateTime scannedAt;
  final Map<String, JunkCategoryInfo> categories;

  int get totalSizeBytes =>
      entries.fold(0, (prev, entry) => prev + entry.sizeBytes);
  int get totalFiles =>
      entries.fold(0, (prev, entry) => prev + entry.fileCount);

  int sizeForCategory(String id) =>
      categories[id]?.sizeBytes ?? 0;
}
