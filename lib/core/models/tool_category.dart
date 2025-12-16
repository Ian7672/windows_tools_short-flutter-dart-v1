class ToolCategory {
  const ToolCategory({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;

  factory ToolCategory.fromJson(Map<String, dynamic> json) {
    return ToolCategory(
      id: json['id'] as String,
      title: json['title'] as String? ?? json['id'] as String,
      description: json['description'] as String? ?? '',
    );
  }
}
