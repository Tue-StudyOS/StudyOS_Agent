import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/agent_config_store.dart';
import 'package:studyos_agent/src/agent_llm_provider.dart';
import 'package:studyos_agent/src/agent_request_runner.dart';
import 'package:studyos_agent/src/mail_repository.dart';
import 'package:studyos_agent/src/mail_tools.dart';
import 'package:studyos_agent/src/memory_store.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/native_bridge.dart';
import 'package:studyos_agent/src/native_tool_router.dart';
import 'package:studyos_agent/src/prompt_context.dart';

void main() {
  test('AgentLlmProviderRegistry resolves registered providers', () {
    final provider = _FakeLlmProvider(provider: AgentProvider.cloud);
    final registry = AgentLlmProviderRegistry(<AgentLlmProvider>[provider]);

    expect(registry.resolve(AgentProvider.cloud), same(provider));
    expect(
      () => registry.resolve(AgentProvider.local),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'AgentRequestRunner delegates requests to the selected provider',
    () async {
      final provider = _FakeLlmProvider(provider: AgentProvider.cloud);
      final runner = AgentRequestRunner(
        bridge: NativeBridge(),
        configStore: AgentConfigStore(),
        memoryStore: MemoryStore(),
        appendMemory: (_) async {},
        onToolTrace: (_) {},
        providerRegistry: AgentLlmProviderRegistry(<AgentLlmProvider>[
          provider,
        ]),
      );

      final response = await runner.send(
        config: const AgentConfig(
          provider: AgentProvider.cloud,
          cloudEndpoint: 'https://example.invalid/v1/chat/completions',
          cloudModel: 'test-model',
          hasApiKey: true,
          localModelId: 'test-local',
          localModelPath: '',
        ),
        sessions: const <ChatSession>[],
        activeSessionId: null,
        userText: 'Hello',
        context: const PromptContext(
          profile: null,
          memory: '',
          worldState: <String, Object?>{},
        ),
        memoryText: 'Saved context',
        readSchedule: () async => 'No schedule.',
        mailTools: MailToolRunner(repository: MailRepository(), profile: null),
      );

      expect(response, 'fake response');
      expect(provider.lastRequest?.userText, 'Hello');
      expect(provider.lastRequest?.memoryText, 'Saved context');
    },
  );

  test(
    'local provider advertises StudyOS mail tools to native models',
    () async {
      final bridge = _FakeNativeBridge('Plain local response.');
      final provider = LocalNativeLlmProvider(bridge);

      final response = await provider.send(
        AgentLlmRequest(
          config: const AgentConfig(
            provider: AgentProvider.local,
            cloudEndpoint: 'https://example.invalid/v1/chat/completions',
            cloudModel: 'test-model',
            hasApiKey: false,
            localModelId: 'test-local',
            localModelPath: '/tmp/model.litertlm',
          ),
          sessions: const <ChatSession>[],
          activeSessionId: null,
          userText: 'Do I have recent mail?',
          context: const PromptContext(
            profile: null,
            memory: '',
            worldState: <String, Object?>{},
          ),
          memoryText: '',
          appendMemory: (_) async {},
          readSchedule: () async => 'No schedule.',
          mailTools: MailToolRunner(
            repository: MailRepository.test(),
            profile: null,
          ),
          onToolTrace: (_) {},
        ),
      );

      expect(response, 'Plain local response.');
      expect(bridge.lastSystemPrompt, contains('get_recent_mail'));
      expect(bridge.lastSystemPrompt, contains('search_mail'));
      expect(bridge.lastSystemPrompt, contains('find_mail_deadlines'));
      expect(
        bridge.lastSystemPrompt,
        isNot(contains(nativeSetFlashlightToolName)),
      );
    },
  );

  test(
    'local provider advertises only supported native tools',
    () async {
      final bridge = _FakeNativeBridge(
        'Plain local response.',
        nativeTools: const <Map<String, Object?>>[
          <String, Object?>{
            'name': nativeDeviceStatusToolName,
            'supported': true,
          },
          <String, Object?>{
            'name': nativeSetFlashlightToolName,
            'supported': false,
          },
        ],
      );
      final provider = LocalNativeLlmProvider(bridge);

      await provider.send(
        AgentLlmRequest(
          config: const AgentConfig(
            provider: AgentProvider.local,
            cloudEndpoint: 'https://example.invalid/v1/chat/completions',
            cloudModel: 'test-model',
            hasApiKey: false,
            localModelId: 'test-local',
            localModelPath: '/tmp/model.litertlm',
          ),
          sessions: const <ChatSession>[],
          activeSessionId: null,
          userText: 'What is my device status?',
          context: const PromptContext(
            profile: null,
            memory: '',
            worldState: <String, Object?>{},
          ),
          memoryText: '',
          appendMemory: (_) async {},
          readSchedule: () async => 'No schedule.',
          mailTools: MailToolRunner(
            repository: MailRepository.test(),
            profile: null,
          ),
          onToolTrace: (_) {},
        ),
      );

      expect(bridge.lastSystemPrompt, contains(nativeDeviceStatusToolName));
      expect(
        bridge.lastSystemPrompt,
        isNot(contains(nativeSetFlashlightToolName)),
      );
    },
  );
}

class _FakeLlmProvider implements AgentLlmProvider {
  _FakeLlmProvider({required this.provider});

  @override
  final AgentProvider provider;

  @override
  String get id => 'fake-${provider.name}';

  @override
  String get displayName => 'Fake ${provider.name} provider';

  AgentLlmRequest? lastRequest;

  @override
  Future<String> send(AgentLlmRequest request) async {
    lastRequest = request;
    return 'fake response';
  }
}

class _FakeNativeBridge extends NativeBridge {
  _FakeNativeBridge(
    this.response, {
    this.nativeTools = const <Map<String, Object?>>[],
  });

  final String response;
  final List<Map<String, Object?>> nativeTools;
  String? lastSystemPrompt;

  @override
  Future<Map<String, Object?>> getCapabilities() async {
    return <String, Object?>{'nativeTools': nativeTools};
  }

  @override
  Future<String> sendMessage(
    String text, {
    String? systemPrompt,
    String? memory,
    String? localModelPath,
  }) async {
    lastSystemPrompt = systemPrompt;
    return response;
  }
}
