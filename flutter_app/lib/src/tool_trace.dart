class ToolTrace {
  const ToolTrace({
    required this.toolName,
    required this.status,
    required this.summary,
    this.callId,
  });

  final String toolName;
  final String status;
  final String summary;
  final String? callId;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'toolName': toolName,
      'status': status,
      'summary': summary,
      if (callId != null) 'callId': callId,
    };
  }

  static ToolTrace fromJson(Map<String, Object?> json) {
    return ToolTrace(
      toolName: json['toolName']?.toString() ?? 'tool',
      status: json['status']?.toString() ?? 'done',
      summary: json['summary']?.toString() ?? '',
      callId: json['callId']?.toString(),
    );
  }
}
