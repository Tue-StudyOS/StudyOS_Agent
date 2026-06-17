import 'agent_config_store.dart';
import 'chat_session_mutation.dart';
import 'cloud_agent_client.dart';
import 'mail_tools.dart';
import 'memory_store.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'prompt_context.dart';

class AgentLlmRequest {
  const AgentLlmRequest({
    required this.config,
    required this.sessions,
    required this.activeSessionId,
    required this.userText,
    required this.context,
    required this.memoryText,
    required this.appendMemory,
    required this.readSchedule,
    required this.mailTools,
    required this.onToolTrace,
  });

  final AgentConfig config;
  final List<ChatSession> sessions;
  final String? activeSessionId;
  final String userText;
  final PromptContext context;
  final String memoryText;
  final Future<void> Function(String text) appendMemory;
  final Future<String> Function() readSchedule;
  final MailToolRunner mailTools;
  final void Function(ToolTrace trace) onToolTrace;
}

abstract class AgentLlmProvider {
  AgentProvider get provider;
  String get id;
  String get displayName;

  Future<String> send(AgentLlmRequest request);
}

class AgentLlmProviderRegistry {
  AgentLlmProviderRegistry(Iterable<AgentLlmProvider> providers) {
    for (final provider in providers) {
      register(provider);
    }
  }

  factory AgentLlmProviderRegistry.defaults({
    required NativeBridge bridge,
    required AgentConfigStore configStore,
    required MemoryStore memoryStore,
    required Future<void> Function(String text) appendMemory,
    required CloudAgentClient cloudClient,
  }) {
    return AgentLlmProviderRegistry(<AgentLlmProvider>[
      LocalNativeLlmProvider(bridge),
      CloudLlmProvider(configStore, memoryStore, appendMemory, cloudClient),
    ]);
  }

  final Map<AgentProvider, AgentLlmProvider> _providers =
      <AgentProvider, AgentLlmProvider>{};

  void register(AgentLlmProvider provider) {
    _providers[provider.provider] = provider;
  }

  AgentLlmProvider resolve(AgentProvider provider) {
    final resolved = _providers[provider];
    if (resolved == null) {
      throw StateError('No LLM provider registered for ${provider.name}.');
    }
    return resolved;
  }
}

class LocalNativeLlmProvider implements AgentLlmProvider {
  const LocalNativeLlmProvider(this._bridge);

  final NativeBridge _bridge;

  @override
  AgentProvider get provider => AgentProvider.local;

  @override
  String get id => 'local-native';

  @override
  String get displayName => 'Local native model';

  @override
  Future<String> send(AgentLlmRequest request) {
    return _bridge.sendMessage(
      request.userText,
      systemPrompt: request.context.systemPrompt(),
      memory: request.memoryText,
      localModelPath: request.config.localModelPath,
    );
  }
}

class CloudLlmProvider implements AgentLlmProvider {
  const CloudLlmProvider(
    this._configStore,
    this._memoryStore,
    this._appendMemory,
    this._cloudClient,
  );

  final AgentConfigStore _configStore;
  final MemoryStore _memoryStore;
  final Future<void> Function(String text) _appendMemory;
  final CloudAgentClient _cloudClient;

  @override
  AgentProvider get provider => AgentProvider.cloud;

  @override
  String get id => 'cloud-openai-compatible';

  @override
  String get displayName => 'OpenAI-compatible cloud model';

  @override
  Future<String> send(AgentLlmRequest request) async {
    final apiKey = await _configStore.readApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const CloudAgentException('Cloud API key is required.');
    }
    return _cloudClient.sendMessage(
      config: request.config,
      apiKey: apiKey,
      history: activeSessionFrom(
        request.sessions,
        request.activeSessionId,
      ).messages,
      userText: request.userText,
      context: request.context,
      appendMemory: _appendMemory,
      readMemory: _memoryStore.read,
      readSchedule: request.readSchedule,
      mailTools: request.mailTools,
      onToolTrace: request.onToolTrace,
    );
  }
}
