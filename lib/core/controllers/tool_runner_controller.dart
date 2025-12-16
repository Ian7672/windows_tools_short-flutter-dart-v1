import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tool_definition.dart';
import '../models/tool_run_state.dart';
import '../services/logs_service.dart';
import '../services/tool_handlers.dart';

class ToolRunnerController extends StateNotifier<ToolRunState> {
  ToolRunnerController({
    required this.toolId,
    required this.handlerRegistry,
    required this.logsController,
    required this.logsService,
  }) : super(const ToolRunState());

  final String toolId;
  final ToolHandlerRegistry handlerRegistry;
  final LogsController logsController;
  final LogsService logsService;

  bool get _isRunning => state.status == ToolRunStatus.running;

  Future<void> preview(ToolDefinition tool) async {
    final handler = handlerRegistry.resolve(tool);
    final result = await handler.preview(tool);
    state = state.copyWith(
      logLines: result.logs,
      message: result.success
          ? 'Preview generated.'
          : (result.logs.isEmpty ? 'Preview failed.' : result.logs.last),
    );
  }

  Future<void> runTool(ToolDefinition tool) async {
    if (_isRunning) return;
    final handler = handlerRegistry.resolve(tool);
    final started = DateTime.now();
    state = state.copyWith(
      status: ToolRunStatus.running,
      logLines: const [],
      startedAt: started,
      message: 'Running ${tool.title}...',
      backupPath: null,
      errorCode: null,
      isApplied: state.isApplied,
    );
    final result = await handler.run(tool);
    final finished = DateTime.now();
    final status =
        result.success ? ToolRunStatus.success : ToolRunStatus.failed;
    state = state.copyWith(
      status: status,
      finishedAt: finished,
      logLines: result.logs,
      backupPath: result.backupPath,
      message: result.success
          ? 'Completed successfully.'
          : 'Failed with code ${result.errorCode ?? -1}',
      errorCode: result.errorCode,
      isApplied: result.success ? true : state.isApplied,
    );
    final entry = await logsService.createEntry(
      toolId: tool.id,
      toolTitle: tool.title,
      status: status.name,
      startedAt: started,
      duration: finished.difference(started),
      backupPath: result.backupPath,
      errorCode: result.errorCode,
      actionSummary: _buildActionSummary(tool),
    );
    await logsController.addEntry(entry);
  }

  Future<void> restoreTool(ToolDefinition tool) async {
    if (_isRunning) return;
    final handler = handlerRegistry.resolve(tool);
    final started = DateTime.now();
    state = state.copyWith(
      status: ToolRunStatus.running,
      logLines: const [],
      startedAt: started,
      message: 'Restoring last backup...',
      errorCode: null,
      isApplied: state.isApplied,
    );
    final result = await handler.restore(tool);
    final finished = DateTime.now();
    final status =
        result.success ? ToolRunStatus.success : ToolRunStatus.failed;
    state = state.copyWith(
      status: status,
      finishedAt: finished,
      logLines: result.logs,
      message: result.success ? 'Restore completed.' : 'Restore failed.',
      errorCode: result.errorCode,
      isApplied: result.success ? false : state.isApplied,
    );
    final entry = await logsService.createEntry(
      toolId: '${tool.id}_restore',
      toolTitle: '${tool.title} (restore)',
      status: status.name,
      startedAt: started,
      duration: finished.difference(started),
      backupPath: null,
      errorCode: result.errorCode,
      actionSummary: 'restore',
    );
    await logsController.addEntry(entry);
  }

  String _buildActionSummary(ToolDefinition tool) {
    final svc = tool.serviceActions.length;
    final reg = tool.registryActions.length;
    final fw = tool.firewallActions.length;
    return '$svc service / $reg registry / $fw firewall actions';
  }
}
