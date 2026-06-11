import 'models.dart';

ToolTrace modelRequestTrace(
  AgentConfig config, {
  required String status,
  required String callId,
}) {
  final name = config.usesCloud
      ? 'model:${config.cloudModel.trim()}'
      : 'model:apple_foundation';
  return ToolTrace(
    toolName: name,
    status: status,
    summary: config.usesCloud
        ? 'Using cloud endpoint ${config.cloudEndpoint}.'
        : 'Local provider is chat-only and has no StudyOS tool bridge.',
    callId: callId,
  );
}
