import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/agent_exception.dart';
import 'package:studyos_agent/src/agent_llm_provider.dart';
import 'package:studyos_agent/src/mail_repository.dart';
import 'package:studyos_agent/src/mail_tools.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/native_bridge.dart';
import 'package:studyos_agent/src/prompt_context.dart';

const _nativeFcConfig = AgentConfig(
  provider: AgentProvider.local,
  cloudEndpoint: 'https://example.invalid/v1/chat/completions',
  cloudModel: 'test-model',
  hasApiKey: false,
  localModelId: 'test-local',
  localModelPath: '/tmp/model.litertlm',
  localToolProtocol: LocalToolProtocol.nativeFunctionCalling,
);

AgentLlmRequest _request(
  NativeBridge bridge, {
  required String userText,
  Future<String> Function()? readMemory,
  void Function(ToolTrace trace)? onToolTrace,
  AgentStreamSink? onDelta,
}) {
  return AgentLlmRequest(
    config: _nativeFcConfig,
    sessions: const <ChatSession>[],
    activeSessionId: null,
    userText: userText,
    context: const PromptContext(
      profile: null,
      memory: '',
      worldState: <String, Object?>{},
    ),
    memoryText: '',
    appendMemory: (_) async {},
    readMemory: readMemory ?? () async => '',
    readSchedule: () async => 'No schedule.',
    mailTools: MailToolRunner(repository: MailRepository.test(), profile: null),
    onToolTrace: onToolTrace ?? (_) {},
    onDelta: onDelta,
  );
}

void main() {
  test('native FC path returns a direct text answer without tools', () async {
    final bridge = _FakeToolBridge(<Map<String, Object?>>[
      <String, Object?>{'type': 'text', 'text': 'Hello, no tools needed.'},
    ]);
    final provider = LocalNativeLlmProvider(bridge);

    final response = await provider.send(
      _request(bridge, userText: 'Hi there'),
    );

    expect(response, 'Hello, no tools needed.');
    // Tools were still declared to the native layer.
    expect(bridge.lastToolSchemas, isNotEmpty);
    expect(
      bridge.lastToolSchemas.any((schema) => schema.contains('read_memories')),
      isTrue,
    );
    expect(bridge.toolResultBatches, isEmpty);
  });

  test(
    'native FC path executes a tool call and feeds the result back',
    () async {
      final bridge = _FakeToolBridge(<Map<String, Object?>>[
        <String, Object?>{
          'type': 'tool_calls',
          'calls': <Object?>[
            <String, Object?>{'name': 'read_memories', 'arguments': '{}'},
          ],
        },
        <String, Object?>{'type': 'text', 'text': 'I used fresh memory.'},
      ]);
      final provider = LocalNativeLlmProvider(bridge);
      final traces = <ToolTrace>[];

      final response = await provider.send(
        _request(
          bridge,
          userText: 'What should I remember?',
          readMemory: () async => 'Fresh memory from disk',
          onToolTrace: traces.add,
        ),
      );

      expect(response, 'I used fresh memory.');
      // The executed tool's output was returned to the native layer.
      expect(bridge.toolResultBatches, hasLength(1));
      final result = bridge.toolResultBatches.single.single;
      expect(result['name'], 'read_memories');
      expect(result['response'], 'Fresh memory from disk');
      // Running + done traces were emitted for the tool.
      expect(
        traces.map((t) => t.status),
        containsAll(<String>['running', 'done']),
      );
    },
  );

  test(
    'native FC path resets the live stream before a tool follow-up',
    () async {
      final bridge = _FakeToolBridge(<Map<String, Object?>>[
        <String, Object?>{
          'type': 'tool_calls',
          'calls': <Object?>[
            <String, Object?>{'name': 'read_memories', 'arguments': '{}'},
          ],
        },
        <String, Object?>{'type': 'text', 'text': 'Answer from tool results.'},
      ]);
      final provider = LocalNativeLlmProvider(bridge);
      final deltas = <AgentStreamDelta>[];

      final response = await provider.send(
        _request(
          bridge,
          userText: 'What should I remember?',
          readMemory: () async => 'Fresh memory',
          onDelta: deltas.add,
        ),
      );

      expect(response, 'Answer from tool results.');
      expect(deltas.where((delta) => delta.reset), hasLength(1));
    },
  );

  test('native FC path ignores unknown tool names', () async {
    final bridge = _FakeToolBridge(<Map<String, Object?>>[
      <String, Object?>{
        'type': 'tool_calls',
        'calls': <Object?>[
          <String, Object?>{'name': 'not_a_real_tool', 'arguments': '{}'},
        ],
      },
    ]);
    final provider = LocalNativeLlmProvider(bridge);

    // No known tool to run, so the loop stops without dispatching tool results.
    await provider.send(_request(bridge, userText: 'Try a bogus tool'));

    expect(bridge.toolResultBatches, isEmpty);
  });

  test('native FC path throws when tool rounds are exhausted', () async {
    // Always ask for a tool: the loop can never resolve to an answer.
    final loopingTurn = <String, Object?>{
      'type': 'tool_calls',
      'calls': <Object?>[
        <String, Object?>{'name': 'read_memories', 'arguments': '{}'},
      ],
    };
    final bridge = _FakeToolBridge(<Map<String, Object?>>[
      loopingTurn,
      loopingTurn,
      loopingTurn,
      loopingTurn,
      loopingTurn,
    ]);
    final provider = LocalNativeLlmProvider(bridge);

    await expectLater(
      provider.send(
        _request(bridge, userText: 'Loop forever', readMemory: () async => 'x'),
      ),
      throwsA(isA<AgentException>()),
    );
  });
}

class _FakeToolBridge extends NativeBridge {
  _FakeToolBridge(this.turns);

  final List<Map<String, Object?>> turns;
  int _index = 0;

  List<String> lastToolSchemas = const <String>[];
  final List<List<Map<String, Object?>>> toolResultBatches =
      <List<Map<String, Object?>>>[];

  Map<String, Object?> _next() {
    final turn = turns[_index.clamp(0, turns.length - 1)];
    _index += 1;
    return turn;
  }

  @override
  Future<Map<String, Object?>> getNativeToolCapabilities() async {
    return const <String, Object?>{'nativeTools': <Map<String, Object?>>[]};
  }

  @override
  Future<Map<String, Object?>> sendMessageWithTools({
    required String text,
    String? systemInstruction,
    required List<String> toolSchemas,
    String? localModelId,
    String? localModelPath,
    String? localBackend,
  }) async {
    lastToolSchemas = toolSchemas;
    return _next();
  }

  @override
  Future<Map<String, Object?>> sendToolResults(
    List<Map<String, Object?>> results,
  ) async {
    toolResultBatches.add(results);
    return _next();
  }
}
