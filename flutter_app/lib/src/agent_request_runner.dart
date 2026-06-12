import 'agent_config_store.dart';
import 'chat_session_mutation.dart';
import 'cloud_agent_client.dart';
import 'memory_store.dart';
import 'model_request_trace.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'prompt_context.dart';

class AgentRequestRunner {
  AgentRequestRunner({
    required this.bridge,
    required this.configStore,
    required this.memoryStore,
    required this.appendMemory,
    required this.onToolTrace,
    CloudAgentClient? cloudClient,
  }) : cloudClient = cloudClient ?? CloudAgentClient();

  final NativeBridge bridge;
  final AgentConfigStore configStore;
  final MemoryStore memoryStore;
  final Future<void> Function(String text) appendMemory;
  final void Function(ToolTrace trace) onToolTrace;
  final CloudAgentClient cloudClient;

  Future<String> send({
    required AgentConfig config,
    required List<ChatSession> sessions,
    required String? activeSessionId,
    required String userText,
    required PromptContext context,
    required String memoryText,
    required Future<String> Function() readSchedule,
  }) async {
    final traceId = 'model-${DateTime.now().microsecondsSinceEpoch}';
    onToolTrace(
      modelRequestTrace(
        config,
        status: 'running',
        callId: traceId,
        localModelName: _localModelName(context.worldState),
      ),
    );
    try {
      final response = config.usesCloud
          ? await _sendCloud(
              config,
              sessions,
              activeSessionId,
              userText,
              context,
              readSchedule,
            )
          : await bridge.sendMessage(
              userText,
              systemPrompt: context.systemPrompt(),
              memory: memoryText,
            );
      onToolTrace(
        modelRequestTrace(
          config,
          status: 'done',
          callId: traceId,
          localModelName: _localModelName(context.worldState),
        ),
      );
      return response;
    } on Object {
      onToolTrace(
        modelRequestTrace(
          config,
          status: 'failed',
          callId: traceId,
          localModelName: _localModelName(context.worldState),
        ),
      );
      rethrow;
    }
  }

  Future<String> _sendCloud(
    AgentConfig config,
    List<ChatSession> sessions,
    String? activeSessionId,
    String userText,
    PromptContext context,
    Future<String> Function() readSchedule,
  ) async {
    final apiKey = await configStore.readApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const CloudAgentException('Cloud API key is required.');
    }
    return cloudClient.sendMessage(
      config: config,
      apiKey: apiKey,
      history: activeSessionFrom(sessions, activeSessionId).messages,
      userText: userText,
      context: context,
      appendMemory: appendMemory,
      readMemory: memoryStore.read,
      readSchedule: readSchedule,
      onToolTrace: onToolTrace,
    );
  }

  String? _localModelName(Map<String, Object?> worldState) {
    return switch (worldState['platform']?.toString()) {
      'ios' => 'apple_foundation',
      'android' => 'gemini_nano',
      _ => null,
    };
  }
}
