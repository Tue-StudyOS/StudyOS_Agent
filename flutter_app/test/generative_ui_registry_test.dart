import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/models.dart';

void main() {
  test('fixture payloads validate for every supported component kind', () {
    final validatedKinds = <GeneratedComponentKind>{};

    for (final payload in generativeUiFixturePayloads) {
      final validation = GenerativeUiRegistry.validate(payload);
      expect(validation.errors, isEmpty);
      expect(validation.component, isNotNull);
      validatedKinds.add(validation.component!.kind);
    }

    expect(validatedKinds, GeneratedComponentKind.values.toSet());
  });

  test('registry rejects unknown component types and missing arguments', () {
    final unknown = GenerativeUiRegistry.validate(<String, Object?>{
      'type': 'freeform_screen',
      'title': 'Unsafe',
      'body': 'Do anything',
    });
    expect(unknown.isValid, isFalse);
    expect(unknown.errors.single, contains('Unsupported component type'));

    final missingArgument = GenerativeUiRegistry.validate(<String, Object?>{
      'type': 'route_hint',
      'title': 'Route',
      'body': 'Leave now',
      'arguments': <String, Object?>{'destination': 'Library'},
    });
    expect(missingArgument.isValid, isFalse);
    expect(missingArgument.errors, contains('Missing string argument: mode'));
  });

  test('registry rejects non-object arguments', () {
    final validation = GenerativeUiRegistry.validate(<String, Object?>{
      'type': 'quick_reply',
      'title': 'Reply',
      'body': 'Ask',
      'arguments': 'reply=hello',
    });

    expect(validation.isValid, isFalse);
    expect(
      validation.errors,
      contains('Field arguments must be an object when present'),
    );
  });

  group('mailTriageComponentPayload', () {
    String inboxJson({bool withMessages = true}) {
      return jsonEncode(<String, Object?>{
        'account': 'linus@uni-tuebingen.de',
        'mailbox': 'INBOX',
        'unread_count': 1,
        'messages': withMessages
            ? <Map<String, Object?>>[
                <String, Object?>{
                  'uid': '4821',
                  'subject': 'Exercise sheet 7',
                  'from_name': 'Prof. Weber',
                  'from_address': 'weber@uni-tuebingen.de',
                  'received_at': '2026-07-08T09:12:00',
                  'preview': 'Please upload before Friday…',
                  'is_unread': true,
                  'is_approved_broadcast': true,
                },
                <String, Object?>{
                  'uid': '4818',
                  'subject': 'Study group notes',
                  'from_name': null,
                  'from_address': 'lena@example.com',
                  'received_at': '2026-07-07T11:05:00',
                  'preview': 'Thanks!',
                  'is_unread': false,
                  'is_approved_broadcast': false,
                },
              ]
            : <Map<String, Object?>>[],
      });
    }

    test('builds a valid mail_list component from a mail summary tool', () {
      final payload = mailTriageComponentPayload(
        'get_recent_mail',
        inboxJson(),
      );
      expect(payload, isNotNull);

      final validation = GenerativeUiRegistry.validate(payload!);
      expect(validation.errors, isEmpty);
      final component = validation.component!;
      expect(component.kind, GeneratedComponentKind.mailList);
      expect(component.title, 'INBOX · 1 unread');

      final messages = component.arguments['messages'] as List<Object?>;
      expect(messages, hasLength(2));
      final first = messages.first as Map<Object?, Object?>;
      expect(first['uid'], '4821');
      expect(first['sender'], 'Prof. Weber');
      expect(first['is_approved_broadcast'], isTrue);
      // Falls back to the address when no display name is present.
      final second = messages[1] as Map<Object?, Object?>;
      expect(second['sender'], 'lena@example.com');
    });

    test('search_mail is also treated as a producer', () {
      expect(
        mailTriageComponentPayload('search_mail', inboxJson()),
        isNotNull,
      );
    });

    test('returns null for non-producer tools', () {
      expect(
        mailTriageComponentPayload('get_schedule', inboxJson()),
        isNull,
      );
    });

    test('returns null for empty inboxes and unparseable output', () {
      expect(
        mailTriageComponentPayload('get_recent_mail', inboxJson(withMessages: false)),
        isNull,
      );
      expect(
        mailTriageComponentPayload('get_recent_mail', 'Mail is not available.'),
        isNull,
      );
    });
  });

  group('deadlineListComponentPayload', () {
    String deadlinesJson({bool withData = true}) {
      return jsonEncode(<String, Object?>{
        'state': withData ? 'fresh' : 'empty',
        'fetched_at': '2026-07-08T09:00:00.000Z',
        'data': withData
            ? <Map<String, Object?>>[
                <String, Object?>{
                  'id': 'ilias:9921',
                  'source': 'ilias',
                  'title': 'ML exercise sheet 7',
                  'courseTitle': 'Machine Learning',
                  'dueAt': '2026-07-10T18:00:00.000Z',
                  'requirement': 'Graded submission',
                  'status': 'open',
                  'target': 'https://ilias.uni-tuebingen.de/goto_9921',
                },
              ]
            : <Map<String, Object?>>[],
      });
    }

    test('builds a valid deadline_list from get_deadlines output', () {
      final payload = deadlineListComponentPayload(
        'get_deadlines',
        deadlinesJson(),
      );
      expect(payload, isNotNull);

      final validation = GenerativeUiRegistry.validate(payload!);
      expect(validation.errors, isEmpty);
      final component = validation.component!;
      expect(component.kind, GeneratedComponentKind.deadlineList);

      final deadlines = component.arguments['deadlines'] as List<Object?>;
      expect(deadlines, hasLength(1));
      final first = deadlines.first as Map<Object?, Object?>;
      expect(first['title'], 'ML exercise sheet 7');
      expect(first['course'], 'Machine Learning');
      expect(first['due_at'], '2026-07-10T18:00:00.000Z');
    });

    test('the shared dispatcher routes each tool to its builder', () {
      expect(
        componentPayloadForTool('get_deadlines', deadlinesJson()),
        isNotNull,
      );
      expect(
        componentPayloadForTool('get_schedule', deadlinesJson()),
        isNull,
      );
    });

    test('returns null for empty results and non-deadline tools', () {
      expect(
        deadlineListComponentPayload('get_deadlines', deadlinesJson(withData: false)),
        isNull,
      );
      expect(
        deadlineListComponentPayload('get_tasks', deadlinesJson()),
        isNull,
      );
    });
  });
}
