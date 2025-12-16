class RunLogEntry {
  RunLogEntry({
    required this.id,
    required this.toolId,
    required this.toolTitle,
    required this.status,
    required this.startedAt,
    required this.durationMs,
    this.backupPath,
    this.errorCode,
    this.actionSummary,
  });

  final String id;
  final String toolId;
  final String toolTitle;
  final String status;
  final DateTime startedAt;
  final int durationMs;
  final String? backupPath;
  final int? errorCode;
  final String? actionSummary;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'toolId': toolId,
      'toolTitle': toolTitle,
      'status': status,
      'startedAt': startedAt.toIso8601String(),
      'durationMs': durationMs,
      'backupPath': backupPath,
      'errorCode': errorCode,
      'actionSummary': actionSummary,
    };
  }

  factory RunLogEntry.fromJson(Map<String, dynamic> json) {
    return RunLogEntry(
      id: json['id'] as String,
      toolId: json['toolId'] as String? ?? 'unknown',
      toolTitle: json['toolTitle'] as String? ?? 'Unknown',
      status: json['status'] as String? ?? 'Unknown',
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
      durationMs: json['durationMs'] as int? ?? 0,
      backupPath: json['backupPath'] as String?,
      errorCode: json['errorCode'] as int?,
      actionSummary: json['actionSummary'] as String?,
    );
  }
}
