import 'dart:io';

import '../models/tool_definition.dart';

class FirewallOperationResult {
  FirewallOperationResult(this.success, this.message, {this.errorCode});

  final bool success;
  final String message;
  final int? errorCode;
}

class FirewallService {
  Future<bool> ruleExists(String ruleName) async {
    final result = await Process.run('netsh', [
      'advfirewall',
      'firewall',
      'show',
      'rule',
      'name=$ruleName',
    ]);
    final combined = '${result.stdout}${result.stderr}'.toLowerCase();
    if (combined.contains('no rules match')) {
      return false;
    }
    return result.exitCode == 0;
  }

  Future<FirewallOperationResult> _deleteRule(String ruleName) async {
    final result = await Process.run('netsh', [
      'advfirewall',
      'firewall',
      'delete',
      'rule',
      'name=$ruleName',
    ]);
    final output = '${result.stdout}${result.stderr}';
    final normalized = output.toLowerCase();
    final success =
        result.exitCode == 0 || normalized.contains('no rules match');
    if (success) {
      return FirewallOperationResult(
        true,
        'Removed existing rule $ruleName.',
      );
    }
    return FirewallOperationResult(
      false,
      'Failed to remove $ruleName: $output',
      errorCode: result.exitCode,
    );
  }

  Future<FirewallOperationResult> _addRule(FirewallAction action) async {
    final args = [
      'advfirewall',
      'firewall',
      'add',
      'rule',
      'name=${action.ruleName}',
      'dir=${action.direction}',
      'action=block',
      if (action.usesProgram)
        'program=${action.programPath}'
      else if (action.serviceName.isNotEmpty)
        'service=${action.serviceName}',
      'enable=yes',
      'profile=any',
    ];
    final result = await Process.run('netsh', args);
    if (result.exitCode == 0) {
      return FirewallOperationResult(
        true,
        'Rule ${action.ruleName} added.',
      );
    }
    return FirewallOperationResult(
      false,
      'Failed to add ${action.ruleName}: ${result.stdout}${result.stderr}',
      errorCode: result.exitCode,
    );
  }

  Future<List<FirewallOperationResult>> applyActions(
    List<FirewallAction> actions,
  ) async {
    final results = <FirewallOperationResult>[];
    for (final action in actions) {
      final cleanupResult = await _deleteRule(action.ruleName);
      results.add(cleanupResult);
      if (!cleanupResult.success) break;

      final addResult = await _addRule(action);
      results.add(addResult);
      if (!addResult.success) break;
    }
    return results;
  }

  Future<List<FirewallOperationResult>> removeRules(
    List<String> ruleNames,
  ) async {
    final results = <FirewallOperationResult>[];
    for (final name in ruleNames) {
      final result = await _deleteRule(name);
      results.add(result);
      if (!result.success) break;
    }
    return results;
  }
}
