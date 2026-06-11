import 'models.dart';

bool hasAttachedContextTrace(ChatSession session) {
  return session.messages.any(
    (message) =>
        message.trace?.toolName == 'get_study_context' &&
        message.trace?.status == 'attached',
  );
}

String contextTraceSummary({
  required OnboardingProfile? profile,
  required String memoryText,
  required Map<String, Object?> worldState,
}) {
  final parts = <String>[
    if (profile != null) 'profile',
    if (memoryText.trim().isNotEmpty) 'memory',
    if (worldState.isNotEmpty) 'device state',
  ];
  return parts.isEmpty
      ? 'No local context available yet.'
      : 'Attached ${parts.join(', ')} to the model request.';
}
