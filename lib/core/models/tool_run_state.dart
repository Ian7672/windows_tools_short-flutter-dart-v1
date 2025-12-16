enum ToolRunStatus { idle, running, success, failed, cancelled }

class ToolRunState {
  const ToolRunState({
    this.status = ToolRunStatus.idle,
    this.logLines = const <String>[],
    this.startedAt,
    this.finishedAt,
    this.message,
    this.backupPath,
    this.errorCode,
    this.isApplied = false,
  });

  final ToolRunStatus status;
  final List<String> logLines;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? message;
  final String? backupPath;
  final int? errorCode;
  final bool isApplied;

  ToolRunState copyWith({
    ToolRunStatus? status,
    List<String>? logLines,
    DateTime? startedAt,
    DateTime? finishedAt,
    String? message,
    String? backupPath,
    int? errorCode,
    bool? isApplied,
  }) {
    return ToolRunState(
      status: status ?? this.status,
      logLines: logLines ?? this.logLines,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      message: message ?? this.message,
      backupPath: backupPath ?? this.backupPath,
      errorCode: errorCode ?? this.errorCode,
      isApplied: isApplied ?? this.isApplied,
    );
  }
}
