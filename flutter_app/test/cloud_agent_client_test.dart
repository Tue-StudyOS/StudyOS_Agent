import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyos_agent/src/agent_exception.dart';
import 'package:studyos_agent/src/cloud_agent_client.dart';
import 'package:studyos_agent/src/cloud_tool_definitions.dart';
import 'package:studyos_agent/src/mail_repository.dart';
import 'package:studyos_agent/src/mail_tools.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/native_tool_router.dart';
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
        'get_mensa_options',
        'search_campus_locations',
        'list_mailboxes',
        'get_recent_mail',
        'search_mail',
        'get_mail_message',
        'find_mail_deadlines',
      ]),
    );
    expect(toolNames, isNot(contains(nativeDeviceStatusToolName)));
  });

  test('cloud tools include only supported native tools', () {
    final toolNames =
        cloudToolDefinitions(
              supportedNativeToolNames: <String>{
                nativeDeviceStatusToolName,
                nativeCreateReminderToolName,
              },
            )
            .map((tool) => tool['function'])
            .whereType<Map>()
            .map((function) => function['name'])
            .toList();

    expect(toolNames, contains(nativeDeviceStatusToolName));
    expect(toolNames, contains(nativeCreateReminderToolName));
    expect(toolNames, isNot(contains(nativeSetFlashlightToolName)));
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
      mailTools: _fakeMailTools(),
      onToolTrace: traces.add,
    );

    expect(response, 'Use the saved morning focus preference.');
    expect(traces.map((trace) => trace.status), <String>['running', 'done']);
    expect(traces.every((trace) => trace.toolName == 'read_memories'), isTrue);
    expect(bodies.first['tool_choice'], 'auto');
    expect(bodies.first['tools'], isA<List>());
    expect(bodies.last['tools'], isA<List>());
  });

  test('runs multiple bounded cloud tool rounds', () async {
    var requestCount = 0;
    final bodies = <Map<String, Object?>>[];
    final client = CloudAgentClient(
      httpClient: MockClient((request) async {
        requestCount += 1;
        bodies.add(jsonDecode(request.body) as Map<String, Object?>);
        if (requestCount == 1) {
          return _toolCallResponse(
            request,
            id: 'call_memory',
            name: 'read_memories',
            arguments: '{}',
          );
        }
        if (requestCount == 2) {
          expect(request.body, contains('Fresh memory'));
          return _toolCallResponse(
            request,
            id: 'call_schedule',
            name: 'get_schedule',
            arguments: '{}',
          );
        }
        expect(request.body, contains('Algorithms 10:00'));
        return _contentResponse(request, 'Use memory and attend Algorithms.');
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
      history: const <ChatMessage>[],
      userText: 'Plan my morning',
      context: const PromptContext(
        profile: null,
        memory: '',
        worldState: <String, Object?>{},
      ),
      appendMemory: (_) async {},
      readMemory: () async => 'Fresh memory',
      readSchedule: () async => 'Algorithms 10:00',
      mailTools: _fakeMailTools(),
      onToolTrace: traces.add,
    );

    expect(response, 'Use memory and attend Algorithms.');
    expect(bodies, hasLength(3));
    expect(bodies[1]['tools'], isA<List>());
    expect(bodies[2]['tools'], isA<List>());
    expect(traces.map((trace) => trace.toolName), <String>[
      'read_memories',
      'read_memories',
      'get_schedule',
      'get_schedule',
    ]);
  });

  test('returns failed cloud tool results to the model', () async {
    var requestCount = 0;
    final bodies = <Map<String, Object?>>[];
    final client = CloudAgentClient(
      httpClient: MockClient((request) async {
        requestCount += 1;
        bodies.add(jsonDecode(request.body) as Map<String, Object?>);
        if (requestCount == 1) {
          return _toolCallResponse(
            request,
            id: 'call_schedule',
            name: 'get_schedule',
            arguments: '{}',
          );
        }
        expect(request.body, contains('Tool failed:'));
        return _contentResponse(
          request,
          'I could not read the schedule, but can still help.',
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
      history: const <ChatMessage>[],
      userText: 'What is next?',
      context: const PromptContext(
        profile: null,
        memory: '',
        worldState: <String, Object?>{},
      ),
      appendMemory: (_) async {},
      readMemory: () async => '',
      readSchedule: () async => throw StateError('schedule unavailable'),
      mailTools: _fakeMailTools(),
      onToolTrace: traces.add,
    );

    expect(response, 'I could not read the schedule, but can still help.');
    expect(bodies, hasLength(2));
    expect(traces.map((trace) => trace.status), <String>['running', 'failed']);
  });

  test('throws when cloud tool rounds are exhausted', () async {
    final client = CloudAgentClient(
      httpClient: MockClient((request) async {
        return _toolCallResponse(
          request,
          id: 'call_memory',
          name: 'read_memories',
          arguments: '{}',
        );
      }),
    );

    await expectLater(
      client.sendMessage(
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
        userText: 'Loop forever',
        context: const PromptContext(
          profile: null,
          memory: '',
          worldState: <String, Object?>{},
        ),
        appendMemory: (_) async {},
        readMemory: () async => '',
        readSchedule: () async => 'No schedule.',
        mailTools: _fakeMailTools(),
        onToolTrace: (_) {},
      ),
      throwsA(isA<AgentException>()),
    );
  });

  test('accepts cloud responses that skip tools', () async {
    final bodies = <Map<String, Object?>>[];
    final client = CloudAgentClient(
      httpClient: MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, Object?>);
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
      userText: 'Plan a study block',
      context: const PromptContext(
        profile: null,
        memory: '',
        worldState: <String, Object?>{},
      ),
      appendMemory: (_) async {},
      readMemory: () async => '',
      readSchedule: () async => 'No timetable has been synced yet.',
      mailTools: _fakeMailTools(),
    );

    expect(response, 'Here is an ungrounded answer.');
    expect(bodies, hasLength(1));
    expect(bodies.single['tool_choice'], 'auto');
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
      mailTools: _fakeMailTools(),
    );

    expect(response, 'Your next lecture is Algorithms.');
  });

  test('cancels promptly while the connection is still stalling', () async {
    // Simulate a misconfigured/unreachable endpoint: the connection never
    // resolves, so the client would otherwise hang until the socket times out.
    final cancelToken = AgentCancelToken();
    final client = CloudAgentClient(
      httpClient: MockClient((request) => Completer<http.Response>().future),
    );

    final future = client.sendMessage(
      config: const AgentConfig(
        provider: AgentProvider.cloud,
        cloudEndpoint: 'https://unreachable.invalid/v1/chat/completions',
        cloudModel: 'openai/gpt-4.1-mini',
        hasApiKey: true,
        localModelId: 'gemma-4-e2b-it',
        localModelPath: '',
      ),
      apiKey: 'secret',
      history: const <ChatMessage>[],
      userText: 'Are you there?',
      context: const PromptContext(
        profile: null,
        memory: '',
        worldState: <String, Object?>{},
      ),
      appendMemory: (_) async {},
      readMemory: () async => '',
      readSchedule: () async => '',
      mailTools: _fakeMailTools(),
      onDelta: (_) {},
      cancelToken: cancelToken,
    );

    cancelToken.cancel();

    await expectLater(future, throwsA(isA<AgentCancelledException>()));
  });

  test('executes read-only mail tool calls', () async {
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
                        'id': 'call_mail',
                        'type': 'function',
                        'function': <String, Object?>{
                          'name': 'search_mail',
                          'arguments': '{"sender":"prof"}',
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
        expect(request.body, contains('Exam response'));
        return http.Response(
          jsonEncode(<String, Object?>{
            'choices': <Object?>[
              <String, Object?>{
                'message': <String, Object?>{
                  'role': 'assistant',
                  'content': 'You got a response from Prof. X.',
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
      userText: 'Did I get a response from Prof. X?',
      context: const PromptContext(
        profile: null,
        memory: '',
        worldState: <String, Object?>{},
      ),
      appendMemory: (_) async {},
      readMemory: () async => '',
      readSchedule: () async => '',
      mailTools: _fakeMailTools(),
    );

    expect(response, 'You got a response from Prof. X.');
  });
}

http.Response _toolCallResponse(
  http.BaseRequest request, {
  required String id,
  required String name,
  required String arguments,
}) {
  return http.Response(
    jsonEncode(<String, Object?>{
      'choices': <Object?>[
        <String, Object?>{
          'message': <String, Object?>{
            'role': 'assistant',
            'content': null,
            'tool_calls': <Object?>[
              <String, Object?>{
                'id': id,
                'type': 'function',
                'function': <String, Object?>{
                  'name': name,
                  'arguments': arguments,
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

http.Response _contentResponse(http.BaseRequest request, String content) {
  return http.Response(
    jsonEncode(<String, Object?>{
      'choices': <Object?>[
        <String, Object?>{
          'message': <String, Object?>{'role': 'assistant', 'content': content},
        },
      ],
    }),
    200,
    request: request,
  );
}

MailToolRunner _fakeMailTools() {
  return MailToolRunner(repository: _FakeMailRepository(), profile: null);
}

class _FakeMailRepository extends MailRepository {
  _FakeMailRepository() : super.test();

  @override
  Future<List<MailboxSummary>> listMailboxes(OnboardingProfile? profile) async {
    return const <MailboxSummary>[
      MailboxSummary(
        name: 'INBOX',
        label: 'Inbox',
        specialUse: 'inbox',
        messageCount: 1,
        unreadCount: 1,
      ),
    ];
  }

  @override
  Future<MailInboxSummary> fetchMailboxSummary(
    OnboardingProfile? profile, {
    String mailbox = 'INBOX',
    int limit = 12,
    bool unreadOnly = false,
    String query = '',
    String sender = '',
    String since = '',
    int scanLimit = 200,
  }) async {
    return const MailInboxSummary(
      account: 'ada42',
      mailbox: 'INBOX',
      unreadCount: 1,
      messages: <MailMessageSummary>[
        MailMessageSummary(
          uid: '7',
          subject: 'Exam response',
          fromName: 'Prof. X',
          fromAddress: 'prof@example.edu',
          receivedAt: 'Tue, 16 Jun 2026 10:00:00 +0200',
          preview: 'The exam registration is confirmed.',
          isUnread: true,
        ),
      ],
    );
  }

  @override
  Future<MailMessageDetail> fetchMessageDetail(
    OnboardingProfile? profile, {
    required String uid,
    String mailbox = 'INBOX',
  }) async {
    return const MailMessageDetail(
      uid: '7',
      mailbox: 'INBOX',
      subject: 'Exam response',
      fromName: 'Prof. X',
      fromAddress: 'prof@example.edu',
      toRecipients: <String>['Ada <ada@example.edu>'],
      ccRecipients: <String>[],
      receivedAt: 'Tue, 16 Jun 2026 10:00:00 +0200',
      preview: 'The exam registration is confirmed.',
      bodyText: 'The exam registration is confirmed.',
      attachmentNames: <String>[],
      isUnread: true,
    );
  }
}
