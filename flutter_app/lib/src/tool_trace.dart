class ToolTrace {
  const ToolTrace({
    required this.toolName,
    required this.status,
    required this.summary,
    this.callId,
    this.component,
  });

  final String toolName;
  final String status;
  final String summary;
  final String? callId;

  /// Optional generative-UI component payload emitted by the tool, validated at
  /// render time by [GenerativeUiRegistry]. Rides the trace so the chat surface
  /// can render a rich card (e.g. mail triage) in place of the plain trace row,
  /// and survives session persistence via [toJson]/[fromJson].
  final Map<String, Object?>? component;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'toolName': toolName,
      'status': status,
      'summary': summary,
      if (callId != null) 'callId': callId,
      if (component != null) 'component': component,
    };
  }

  static ToolTrace fromJson(Map<String, Object?> json) {
    final rawComponent = json['component'];
    return ToolTrace(
      toolName: json['toolName']?.toString() ?? 'tool',
      status: json['status']?.toString() ?? 'done',
      summary: json['summary']?.toString() ?? '',
      callId: json['callId']?.toString(),
      component: rawComponent is Map
          ? Map<String, Object?>.from(rawComponent)
          : null,
    );
  }
}
