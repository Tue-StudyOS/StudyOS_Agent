import 'agent_config_store.dart';
import 'agent_request_runner.dart';
import 'chat_session_mutation.dart';
import 'initial_context_trace.dart';
import 'memory_store.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'prompt_context.dart';

Future<String> sendAgentMessage({
  required AgentConfig config,
  required NativeBridge bridge,
  required AgentConfigStore configStore,
  required MemoryStore memoryStore,
  required OnboardingProfile? profile,
  required List<ChatSession> sessions,
  required String? activeSessionId,
  required String memoryText,
  required Map<String, Object?> worldState,
  required String userText,
  required Future<void> Function(String text) appendMemory,
  required void Function(ToolTrace trace) onToolTrace,
}) {
  final context = PromptContext(
    profile: profile,
    memory: memoryText,
    worldState: worldState,
  );
  final trace = initialContextTrace(
    activeSession: activeSessionFrom(sessions, activeSessionId),
    profile: profile,
    memoryText: memoryText,
    worldState: worldState,
  );
  if (trace != null) onToolTrace(trace);
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
  );
}
