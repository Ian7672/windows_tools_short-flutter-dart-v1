import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../constants/app_strings.dart';
import '../models/tool_category.dart';
import '../models/tool_definition.dart';
import '../models/tools_manifest.dart';
import 'app_paths.dart';

class ToolsManifestRepository {
  const ToolsManifestRepository(this._paths);

  final AppPaths _paths;

  Future<ToolsManifest> load() async {
    final manifestJson =
        await rootBundle.loadString(AppStrings.manifestAsset);
    final decoded = jsonDecode(manifestJson) as Map<String, dynamic>;
    final categoriesJson = decoded['categories'] as List<dynamic>? ?? [];
    final toolsJson = decoded['tools'] as List<dynamic>? ?? [];
    final customRaw = await _readCustomTools();

    final categories = categoriesJson
        .map((json) => ToolCategory.fromJson(json as Map<String, dynamic>))
        .toList();

    final tools = [
      ...toolsJson.map(
        (raw) => ToolDefinition.fromJson(raw as Map<String, dynamic>),
      ),
      ...customRaw.map((raw) => ToolDefinition.fromJson(raw)),
    ];
    return ToolsManifest(categories: categories, tools: tools);
  }

  Future<String> addCustomFirewallTool({
    required String title,
    required String description,
    required List<String> serviceNames,
    required List<String> programPaths,
  }) async {
    final custom = await _readCustomTools();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = 'customFirewall_$timestamp';
    final rulePrefix = '$title -';
    final List<Map<String, dynamic>> firewallActions = [];
    for (final service in serviceNames) {
      firewallActions.add({
        'ruleName': '$rulePrefix $service - OUT',
        'direction': 'out',
        'serviceName': service,
        'group': 'LWT Custom Updaters',
      });
    }
    for (final program in programPaths) {
      final basename = p.basename(program);
      firewallActions.add({
        'ruleName': '$rulePrefix $basename - OUT',
        'direction': 'out',
        'serviceName': '',
        'programPath': program,
        'group': 'LWT Custom Updaters',
      });
    }
    final entry = {
      'id': id,
      'title': title,
      'category': 'updater',
      'description': description,
      'requiresAdmin': true,
      'riskLevel': 'low',
      'allowCancel': true,
      'serviceActions': <Map<String, dynamic>>[],
      'registryActions': <Map<String, dynamic>>[],
      'firewallActions': firewallActions,
    };
    custom.add(entry);
    await _writeCustomTools(custom);
    return id;
  }

  Future<List<Map<String, dynamic>>> _readCustomTools() async {
    final file = _customToolsFile;
    if (!file.existsSync()) {
      return [];
    }
    try {
      final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
      return raw
          .whereType<Map<String, dynamic>>()
          .toList(growable: true);
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeCustomTools(
      List<Map<String, dynamic>> data) async {
    final file = _customToolsFile;
    final encoded = jsonEncode(data);
    await file.writeAsString(encoded);
  }

  File get _customToolsFile =>
      File(p.join(_paths.root.path, 'custom_tools.json'));
}
