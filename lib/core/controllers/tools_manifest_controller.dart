import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tool_definition.dart';
import '../models/tools_manifest.dart';
import '../services/tools_manifest_repository.dart';

class ToolsManifestController
    extends StateNotifier<AsyncValue<ToolsManifest>> {
  ToolsManifestController(
    this._repository,
  ) : super(const AsyncValue.loading()) {
    refresh();
  }

  final ToolsManifestRepository _repository;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final manifest = await _repository.load();
      state = AsyncValue.data(manifest);
    } catch (err, stack) {
      state = AsyncValue.error(err, stack);
    }
  }

  Future<String> addCustomFirewallTool({
    required String title,
    required String description,
    required List<String> serviceNames,
    required List<String> programPaths,
  }) async {
    final id = await _repository.addCustomFirewallTool(
      title: title,
      description: description,
      serviceNames: serviceNames,
      programPaths: programPaths,
    );
    await refresh();
    return id;
  }

  ToolDefinition? findById(String toolId) {
    final manifest = state.valueOrNull;
    if (manifest == null || manifest.tools.isEmpty) {
      return null;
    }
    return manifest.tools.firstWhere(
      (tool) => tool.id == toolId,
      orElse: () => manifest.tools.first,
    );
  }
}
