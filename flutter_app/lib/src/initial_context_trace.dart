import 'context_trace_summary.dart';
import 'models.dart';

ToolTrace? initialContextTrace({
  required ChatSession activeSession,
  required OnboardingProfile? profile,
  required String memoryText,
  required Map<String, Object?> worldState,
}) {
  if (hasAttachedContextTrace(activeSession)) return null;
  return ToolTrace(
    toolName: 'get_study_context',
    status: 'attached',
    summary: contextTraceSummary(
      profile: profile,
      memoryText: memoryText,
      worldState: worldState,
    ),
  );
}
