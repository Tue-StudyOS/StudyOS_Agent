import 'agent_config_store.dart';
import 'agent_llm_provider.dart';
import 'cloud_agent_client.dart';
import 'mail_tools.dart';
import 'memory_store.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'native_tool_router.dart';
import 'prompt_context.dart';

class AgentRequestRunner {
  AgentRequestRunner({
    required this.bridge,
    required this.configStore,
    required this.memoryStore,
    required this.appendMemory,
    required this.onToolTrace,
    CloudAgentClient? cloudClient,
    AgentLlmProviderRegistry? providerRegistry,
  }) : providerRegistry =
           providerRegistry ??
           AgentLlmProviderRegistry.defaults(
             bridge: bridge,
             configStore: configStore,
             memoryStore: memoryStore,
             appendMemory: appendMemory,
             cloudClient:
                 cloudClient ??
                 CloudAgentClient(nativeTools: NativeToolRouter(bridge)),
           );

  final NativeBridge bridge;
  final AgentConfigStore configStore;
  final MemoryStore memoryStore;
  final Future<void> Function(String text) appendMemory;
  final void Function(ToolTrace trace) onToolTrace;
  final AgentLlmProviderRegistry providerRegistry;

  Future<String> send({
    required AgentConfig config,
    required List<ChatSession> sessions,
    required String? activeSessionId,
    required String userText,
    required PromptContext context,
    required String memoryText,
    required Future<String> Function() readSchedule,
    required MailToolRunner mailTools,
    AgentStreamSink? onDelta,
    AgentCancelToken? cancelToken,
  }) async {
    final provider = providerRegistry.resolve(config.provider);
    return provider.send(
      AgentLlmRequest(
        config: config,
        sessions: sessions,
        activeSessionId: activeSessionId,
        userText: userText,
        context: context,
        memoryText: memoryText,
        appendMemory: appendMemory,
        readMemory: memoryStore.read,
        readSchedule: readSchedule,
        mailTools: mailTools,
        onToolTrace: onToolTrace,
        onDelta: onDelta,
        cancelToken: cancelToken,
      ),
    );
  }
}
