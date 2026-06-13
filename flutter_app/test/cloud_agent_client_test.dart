import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyos_agent/src/cloud_agent_client.dart';
import 'package:studyos_agent/src/cloud_tool_definitions.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/prompt_context.dart';

void main() {
  test('cloud tools are built from the StudyOS catalog', () {
    final toolNames = cloudToolDefinitions()
        .map((tool) => tool['function'])
        .whereType<Map>()
        .map((function) => function['name'])
        .toList();

    expect(
      toolNames,
      containsAll(<String>[
        'append_memory',
        'read_memories',
        'get_study_context',
        'get_schedule',
      ]),
    );
  });

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
        localModelId: 'gemma-4-e2b-it',
        localModelPath: '',
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
      readSchedule: () async => 'No timetable has been synced yet.',
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
          localModelId: 'gemma-4-e2b-it',
          localModelPath: '',
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
        readSchedule: () async => 'No timetable has been synced yet.',
      ),
      throwsA(isA<CloudAgentException>()),
    );
  });

  test('executes get_schedule tool calls', () async {
    var requestCount = 0;
    final client = CloudAgentClient(
      httpClient: MockClient((request) async {
        requestCount += 1;
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
                        'id': 'call_schedule',
                        'type': 'function',
                        'function': <String, Object?>{
                          'name': 'get_schedule',
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
        expect(request.body, contains('Algorithms 10:00'));
        return http.Response(
          jsonEncode(<String, Object?>{
            'choices': <Object?>[
              <String, Object?>{
                'message': <String, Object?>{
                  'role': 'assistant',
                  'content': 'Your next lecture is Algorithms.',
                },
              },
            ],
          }),
          200,
          request: request,
        );
      }),
    );

    final response = await client.sendMessage(
      config: const AgentConfig(
        provider: AgentProvider.cloud,
        cloudEndpoint: 'https://openrouter.ai/api/v1/chat/completions',
        cloudModel: 'openai/gpt-4.1-mini',
        hasApiKey: true,
        localModelId: 'gemma-4-e2b-it',
        localModelPath: '',
      ),
      apiKey: 'secret',
      history: const <ChatMessage>[],
      userText: 'What is my next lecture?',
      context: const PromptContext(
        profile: null,
        memory: '',
        worldState: <String, Object?>{},
      ),
      appendMemory: (_) async {},
      readMemory: () async => '',
      readSchedule: () async => 'Algorithms 10:00',
    );

    expect(response, 'Your next lecture is Algorithms.');
  });
}
