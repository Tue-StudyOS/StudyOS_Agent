import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/agent_config_store.dart';
import 'package:studyos_agent/src/agent_llm_provider.dart';
import 'package:studyos_agent/src/agent_request_runner.dart';
import 'package:studyos_agent/src/agent_exception.dart';
import 'package:studyos_agent/src/mail_repository.dart';
import 'package:studyos_agent/src/mail_tools.dart';
import 'package:studyos_agent/src/memory_store.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/native_bridge.dart';
import 'package:studyos_agent/src/native_tool_router.dart';
import 'package:studyos_agent/src/prompt_context.dart';
import 'package:studyos_agent/src/private_study_tools.dart';

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
      final privateTools = _FakePrivateStudyTools();
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
        privateStudyTools: privateTools,
      );

      expect(response, 'fake response');
      expect(provider.lastRequest?.userText, 'Hello');
      expect(provider.lastRequest?.memoryText, 'Saved context');
      expect(provider.lastRequest?.privateStudyTools, same(privateTools));
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
          readMemory: () async => '',
          readSchedule: () async => 'No schedule.',
          mailTools: MailToolRunner(
            repository: MailRepository.test(),
            profile: null,
          ),
          onToolTrace: (_) {},
        ),
      );

      expect(response, 'Plain local response.');
      expect(bridge.lastSystemInstruction, contains('search_talks'));
      expect(bridge.lastSystemInstruction, contains('get_recent_mail'));
      expect(bridge.lastSystemInstruction, contains('search_mail'));
      expect(bridge.lastSystemInstruction, contains('find_mail_deadlines'));
      expect(
        bridge.lastSystemInstruction,
        isNot(contains(nativeSetFlashlightToolName)),
      );
    },
  );

  test('local provider advertises only supported native tools', () async {
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
        readMemory: () async => '',
        readSchedule: () async => 'No schedule.',
        mailTools: MailToolRunner(
          repository: MailRepository.test(),
          profile: null,
        ),
        onToolTrace: (_) {},
      ),
    );

    expect(bridge.lastSystemInstruction, contains(nativeDeviceStatusToolName));
    expect(
      bridge.lastSystemInstruction,
      isNot(contains(nativeSetFlashlightToolName)),
    );
  });

  test('local provider reads fresh memory during tool execution', () async {
    final prompts = <String>[];
    final bridge = _FakeNativeBridge.sequence(<String>[
      '[TOOL:read_memories:{}]',
      'I used fresh memory.',
    ], prompts: prompts);
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
        userText: 'What should I remember?',
        context: const PromptContext(
          profile: null,
          memory: 'Stale memory snapshot',
          worldState: <String, Object?>{},
        ),
        memoryText: 'Stale memory snapshot',
        appendMemory: (_) async {},
        readMemory: () async => 'Fresh memory from disk',
        readSchedule: () async => 'No schedule.',
        mailTools: MailToolRunner(
          repository: MailRepository.test(),
          profile: null,
        ),
        onToolTrace: (_) {},
      ),
    );

    expect(response, 'I used fresh memory.');
    expect(prompts.last, contains('Fresh memory from disk'));
    expect(prompts.last, isNot(contains('Stale memory snapshot')));
    // The system instruction is installed once and reused verbatim across the
    // tool round rather than rebuilt per message.
    expect(bridge.systemInstructions.toSet(), hasLength(1));
  });

  test('local provider keeps stable context in the system instruction and '
      'ephemeral context on the turn', () async {
    final prompts = <String>[];
    final bridge = _FakeNativeBridge.sequence(<String>[
      'Plain local response.',
    ], prompts: prompts);
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
        userText: 'How is my day?',
        context: const PromptContext(
          profile: null,
          memory: 'Prefers morning study blocks.',
          worldState: <String, Object?>{'platform': 'test-device'},
        ),
        memoryText: 'Prefers morning study blocks.',
        appendMemory: (_) async {},
        readMemory: () async => '',
        readSchedule: () async => 'No schedule.',
        mailTools: MailToolRunner(
          repository: MailRepository.test(),
          profile: null,
        ),
        onToolTrace: (_) {},
      ),
    );

    // Stable content is the system instruction; volatile context is not.
    expect(
      bridge.lastSystemInstruction,
      contains('Prefers morning study blocks.'),
    );
    expect(
      bridge.lastSystemInstruction,
      isNot(contains('Current local timestamp')),
    );

    // The volatile per-turn context rides the message with the user text.
    expect(prompts.single, contains('Current local timestamp'));
    expect(prompts.single, contains('test-device'));
    expect(prompts.single, contains('How is my day?'));
  });

  test(
    'local provider resets the live stream before a tool follow-up',
    () async {
      final bridge = _FakeNativeBridge.sequence(<String>[
        '[TOOL:read_memories:{}]',
        'Answer from tool results.',
      ]);
      final provider = LocalNativeLlmProvider(bridge);
      final deltas = <AgentStreamDelta>[];

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
          userText: 'What should I remember?',
          context: const PromptContext(
            profile: null,
            memory: '',
            worldState: <String, Object?>{},
          ),
          memoryText: '',
          appendMemory: (_) async {},
          readMemory: () async => 'Fresh memory from disk',
          readSchedule: () async => 'No schedule.',
          mailTools: MailToolRunner(
            repository: MailRepository.test(),
            profile: null,
          ),
          onToolTrace: (_) {},
          onDelta: deltas.add,
        ),
      );

      expect(response, 'Answer from tool results.');
      // The bracketed tool directive turn is cleared before the answer streams.
      expect(deltas.where((delta) => delta.reset), hasLength(1));
    },
  );

  test('local provider throws when tool rounds are exhausted', () async {
    final bridge = _FakeNativeBridge('[TOOL:read_memories:{}]');
    final provider = LocalNativeLlmProvider(bridge);

    await expectLater(
      provider.send(
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
          userText: 'Loop forever',
          context: const PromptContext(
            profile: null,
            memory: '',
            worldState: <String, Object?>{},
          ),
          memoryText: '',
          appendMemory: (_) async {},
          readMemory: () async => '',
          readSchedule: () async => 'No schedule.',
          mailTools: MailToolRunner(
            repository: MailRepository.test(),
            profile: null,
          ),
          onToolTrace: (_) {},
        ),
      ),
      throwsA(isA<AgentException>()),
    );
  });
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

class _FakePrivateStudyTools implements PrivateStudyToolRunner {
  @override
  Future<String> execute(String toolName, String arguments) async => '{}';

  @override
  void invalidate() {}
}

class _FakeNativeBridge extends NativeBridge {
  _FakeNativeBridge(
    this.response, {
    this.nativeTools = const <Map<String, Object?>>[],
  }) : responses = null,
       prompts = null;

  _FakeNativeBridge.sequence(this.responses, {this.prompts})
    : response = '',
      nativeTools = const <Map<String, Object?>>[];

  final String response;
  final List<String>? responses;
  final List<String>? prompts;
  final List<Map<String, Object?>> nativeTools;
  String? lastSystemInstruction;
  final List<String?> systemInstructions = <String?>[];
  int _responseIndex = 0;

  @override
  Future<Map<String, Object?>> getNativeToolCapabilities() async {
    return <String, Object?>{'nativeTools': nativeTools};
  }

  @override
  Future<String> sendMessage(
    String text, {
    String? systemInstruction,
    String? localModelId,
    String? localModelPath,
    String? localBackend,
  }) async {
    lastSystemInstruction = systemInstruction;
    systemInstructions.add(systemInstruction);
    prompts?.add(text);
    final queued = responses;
    if (queued == null) return response;
    final index = _responseIndex.clamp(0, queued.length - 1).toInt();
    _responseIndex += 1;
    return queued[index];
  }
}
