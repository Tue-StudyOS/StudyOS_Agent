import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyos_agent/src/cloud_agent_client.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/prompt_context.dart';

void main() {
  test('emits traces for cloud tool calls', () async {
    var requestCount = 0;
    final bodies = <Map<String, Object?>>[];
    final client = CloudAgentClient(
      httpClient: MockClient((request) async {
        requestCount += 1;
        bodies.add(jsonDecode(request.body) as Map<String, Object?>);
        if (requestCount == 1) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'choices': <Object?>[
                <String, Object?>{
                  'message': <String, Object?>{
                    'role': 'assistant',
                    'content': null,
                    'tool_calls': <Object?>[
                      <String, Object?>{
                        'id': 'call_1',
                        'type': 'function',
                        'function': <String, Object?>{
                          'name': 'read_memories',
                          'arguments': '{}',
                        },
                      },
                    ],
                  },
                },
              ],
            }),
            200,
            request: request,
          );
        }

        return http.Response(
          jsonEncode(<String, Object?>{
            'choices': <Object?>[
              <String, Object?>{
                'message': <String, Object?>{
                  'role': 'assistant',
                  'content': 'Use the saved morning focus preference.',
                },
              },
            ],
          }),
          200,
          request: request,
        );
      }),
    );
    final traces = <ToolTrace>[];

    final response = await client.sendMessage(
      config: const AgentConfig(
        provider: AgentProvider.cloud,
        cloudEndpoint: 'https://openrouter.ai/api/v1/chat/completions',
        cloudModel: 'openai/gpt-4.1-mini',
        hasApiKey: true,
      ),
      apiKey: 'secret',
      history: <ChatMessage>[
        ChatMessage.toolTrace(
          toolName: 'get_study_context',
          status: 'attached',
          summary: 'Attached profile.',
        ),
      ],
      userText: 'Plan a study block',
      context: const PromptContext(
        profile: null,
        memory: '- Prefers morning study blocks.',
        worldState: <String, Object?>{},
      ),
      appendMemory: (_) async {},
      readMemory: () async => '- Prefers morning study blocks.',
      onToolTrace: traces.add,
    );

    expect(response, 'Use the saved morning focus preference.');
    expect(traces.map((trace) => trace.status), <String>['running', 'done']);
    expect(traces.every((trace) => trace.toolName == 'read_memories'), isTrue);
    expect(bodies.first['tool_choice'], 'required');
    expect(bodies.first['tools'], isA<List>());
    expect(bodies.last.containsKey('tools'), isFalse);
  });

  test('rejects cloud responses that skip tools', () async {
    final client = CloudAgentClient(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object?>{
            'choices': <Object?>[
              <String, Object?>{
                'message': <String, Object?>{
                  'role': 'assistant',
                  'content': 'Here is an ungrounded answer.',
                },
              },
            ],
          }),
          200,
          request: request,
        );
      }),
    );

    expect(
      () => client.sendMessage(
        config: const AgentConfig(
          provider: AgentProvider.cloud,
          cloudEndpoint: 'https://openrouter.ai/api/v1/chat/completions',
          cloudModel: 'openai/gpt-4.1-mini',
          hasApiKey: true,
        ),
        apiKey: 'secret',
        history: const <ChatMessage>[],
        userText: 'Plan a study block',
        context: const PromptContext(
          profile: null,
          memory: '',
          worldState: <String, Object?>{},
        ),
        appendMemory: (_) async {},
        readMemory: () async => '',
      ),
      throwsA(isA<CloudAgentException>()),
    );
  });
}
