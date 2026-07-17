import 'agent_config_store.dart';
import 'agent_request_runner.dart';
import 'mail_tools.dart';
import 'memory_store.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'prompt_context.dart';
import 'public_study_tools.dart';

Future<String> _unavailableTalks(String query, int limit) async =>
    'Tübingen Talks are not available.';

Future<String> sendAgentMessage({
  required AgentConfig config,
  required NativeBridge bridge,
  required AgentConfigStore configStore,
  required MemoryStore memoryStore,
  required OnboardingProfile? profile,
  required List<ChatSession> sessions,
  required String? activeSessionId,
  required String memoryText,
  required TimetableSnapshot? timetable,
  required Map<String, Object?> worldState,
  required String userText,
  required Future<void> Function(String text) appendMemory,
  required Future<String> Function() readSchedule,
  required Future<String> Function() readAcademicStatus,
  Future<String> Function(String query, int limit) searchTalks =
      _unavailableTalks,
  required MailToolRunner mailTools,
  required PublicStudyToolRunner publicStudyTools,
  required void Function(ToolTrace trace) onToolTrace,
  AgentStreamSink? onDelta,
  AgentCancelToken? cancelToken,
}) {
  final context = PromptContext(
    profile: profile,
    memory: memoryText,
    worldState: worldState,
    timetable: timetable,
  );
  return AgentRequestRunner(
    bridge: bridge,
    configStore: configStore,
    memoryStore: memoryStore,
    appendMemory: appendMemory,
    onToolTrace: onToolTrace,
  ).send(
    config: config,
    sessions: sessions,
    activeSessionId: activeSessionId,
    userText: userText,
    context: context,
    memoryText: memoryText,
    readSchedule: readSchedule,
    readAcademicStatus: readAcademicStatus,
    searchTalks: searchTalks,
    mailTools: mailTools,
    publicStudyTools: publicStudyTools,
    onDelta: onDelta,
    cancelToken: cancelToken,
  );
}
