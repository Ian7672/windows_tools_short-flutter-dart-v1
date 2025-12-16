import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/run_log_entry.dart';
import 'app_paths.dart';

class LogsService {
  LogsService(this._paths);

  final AppPaths _paths;
  final _uuid = const Uuid();

  File get _historyFile => File(p.join(_paths.logsDir.path, 'history.json'));

  Future<List<RunLogEntry>> readAll() async {
    if (!await _historyFile.exists()) {
      return <RunLogEntry>[];
    }
    final raw = await _historyFile.readAsString();
    if (raw.trim().isEmpty) {
      return <RunLogEntry>[];
    }
    final data = jsonDecode(raw) as List<dynamic>;
    return data
        .map((item) => RunLogEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> writeAll(List<RunLogEntry> entries) async {
    final data = entries.map((e) => e.toJson()).toList();
    await _historyFile.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  Future<RunLogEntry> createEntry({
    required String toolId,
    required String toolTitle,
    required String status,
    required DateTime startedAt,
    required Duration duration,
    String? backupPath,
    int? errorCode,
    String? actionSummary,
  }) async {
    return RunLogEntry(
      id: _uuid.v4(),
      toolId: toolId,
      toolTitle: toolTitle,
      status: status,
      startedAt: startedAt,
      durationMs: duration.inMilliseconds,
      backupPath: backupPath,
      errorCode: errorCode,
      actionSummary: actionSummary,
    );
  }
}

class LogsController extends StateNotifier<List<RunLogEntry>> {
  LogsController(this._service) : super(const []) {
    _hydrate();
  }

  final LogsService _service;

  Future<void> _hydrate() async {
    final entries = await _service.readAll();
    state = entries;
  }

  Future<void> addEntry(RunLogEntry entry) async {
    final updated = [...state, entry];
    state = updated;
    await _service.writeAll(updated);
  }

  Future<void> cleanup(int retentionDays) async {
    final threshold = DateTime.now().subtract(Duration(days: retentionDays));
    final updated =
        state.where((entry) => entry.startedAt.isAfter(threshold)).toList();
    state = updated;
    await _service.writeAll(updated);
  }

  Future<void> clearAll() async {
    state = const [];
    await _service.writeAll(state);
  }
}
