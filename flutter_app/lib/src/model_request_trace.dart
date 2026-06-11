import 'models.dart';

ToolTrace modelRequestTrace(
  AgentConfig config, {
  required String status,
  required String callId,
  String? localModelName,
}) {
  final name = config.usesCloud
      ? 'model:${config.cloudModel.trim()}'
      : 'model:${localModelName ?? 'native_local'}';
  return ToolTrace(
    toolName: name,
    status: status,
    summary: _summary(config, localModelName),
    callId: callId,
  );
}

String _summary(AgentConfig config, String? localModelName) {
  if (config.usesCloud) {
    return 'Using cloud endpoint ${config.cloudEndpoint}.';
  }
  return switch (localModelName) {
    'apple_foundation' => 'Using Apple Foundation Models with StudyOS tools.',
    'gemini_nano' =>
      'Using Android Gemini Nano Prompt API without native tool calls.',
    _ => 'Using native local provider.',
  };
}
