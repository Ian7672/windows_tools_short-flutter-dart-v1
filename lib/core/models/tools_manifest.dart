import 'tool_category.dart';
import 'tool_definition.dart';

class ToolsManifest {
  const ToolsManifest({
    required this.categories,
    required this.tools,
  });

  final List<ToolCategory> categories;
  final List<ToolDefinition> tools;
}
