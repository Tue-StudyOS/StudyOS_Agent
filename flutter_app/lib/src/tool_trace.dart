class ToolTrace {
  const ToolTrace({
    required this.toolName,
    required this.status,
    required this.summary,
  });

  final String toolName;
  final String status;
  final String summary;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'toolName': toolName,
      'status': status,
      'summary': summary,
    };
  }

  static ToolTrace fromJson(Map<String, Object?> json) {
    return ToolTrace(
      toolName: json['toolName']?.toString() ?? 'tool',
      status: json['status']?.toString() ?? 'done',
      summary: json['summary']?.toString() ?? '',
    );
  }
}
