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

  group('talkListComponentPayload', () {
    String talksJson({bool withItems = true}) {
      return jsonEncode(<String, Object?>{
        'scope': 'upcoming',
        'query': 'ml',
        'items': withItems
            ? <Map<String, Object?>>[
                <String, Object?>{
                  'id': 42,
                  'title': 'Foundation models for science',
                  'timestamp': '2026-12-09T16:15:00.000Z',
                  'speaker_name': 'Dr. Amelie Roth',
                  'location': 'Kupferbau',
                  'tags': <Object?>[],
                },
              ]
            : <Map<String, Object?>>[],
      });
    }

    test('builds a valid talk_list from search_talks output', () {
      final payload = talkListComponentPayload('search_talks', talksJson());
      expect(payload, isNotNull);

      final validation = GenerativeUiRegistry.validate(payload!);
      expect(validation.errors, isEmpty);
      expect(validation.component!.kind, GeneratedComponentKind.talkList);

      final talks = validation.component!.arguments['talks'] as List<Object?>;
      final first = talks.first as Map<Object?, Object?>;
      expect(first['title'], 'Foundation models for science');
      expect(first['speaker'], 'Dr. Amelie Roth');
      expect(first['timestamp'], '2026-12-09T16:15:00.000Z');
    });

    test('the dispatcher routes search_talks; empty items yield no card', () {
      expect(componentPayloadForTool('search_talks', talksJson()), isNotNull);
      expect(
        talkListComponentPayload('search_talks', talksJson(withItems: false)),
        isNull,
      );
    });
  });

  group('academicStatusComponentPayload', () {
    String statusJson({bool withEntries = true}) {
      return jsonEncode(<String, Object?>{
        'term': 'WS 2026/27',
        'entries': withEntries
            ? <Map<String, Object?>>[
                <String, Object?>{
                  'category': 'Exams',
                  'title': 'ML written exam',
                  'status': 'Registered',
                  'semester': 'WS 2026/27',
                },
              ]
            : <Map<String, Object?>>[],
      });
    }

    test('builds a valid academic_status from get_academic_status output', () {
      final payload = academicStatusComponentPayload(
        'get_academic_status',
        statusJson(),
      );
      expect(payload, isNotNull);

      final validation = GenerativeUiRegistry.validate(payload!);
      expect(validation.errors, isEmpty);
      final component = validation.component!;
      expect(component.kind, GeneratedComponentKind.academicStatus);
      expect(component.title, 'Academic status · WS 2026/27');

      final entries = component.arguments['entries'] as List<Object?>;
      final first = entries.first as Map<Object?, Object?>;
      expect(first['category'], 'Exams');
      expect(first['status'], 'Registered');
    });

    test('empty entries and non-status tools yield no card', () {
      expect(
        academicStatusComponentPayload(
          'get_academic_status',
          statusJson(withEntries: false),
        ),
        isNull,
      );
      expect(
        componentPayloadForTool('get_recent_mail', statusJson()),
        isNull,
      );
    });
  });

  group('studyProgressComponentPayload', () {
    String plannerJson({bool withModules = true}) {
      return jsonEncode(<String, Object?>{
        'state': 'fresh',
        'data': <String, Object?>{
          'title': 'M.Sc. Machine Learning',
          'pageUrl': 'https://alma.uni-tuebingen.de/planner',
          'modules': withModules
              ? <Map<String, Object?>>[
                  <String, Object?>{
                    'rowIndex': 0,
                    'columnStart': 0,
                    'columnSpan': 1,
                    'title': 'Core ML',
                    'number': 'ML-4100',
                    'creditsEarned': 27,
                    'creditsRequired': 30,
                    'creditsSummary': '27 / 30 ECTS',
                  },
                  <String, Object?>{
                    'rowIndex': 1,
                    'columnStart': 0,
                    'columnSpan': 1,
                    'title': 'Theory',
                    'creditsEarned': 18,
                    'creditsRequired': 30,
                  },
                ]
              : <Map<String, Object?>>[],
          'viewState': <String, Object?>{
            'showRecommendedPlan': true,
            'showMyModules': true,
            'showAlternativeSemesters': false,
          },
        },
      });
    }

    test('builds a study_progress card and totals the ECTS', () {
      final payload = studyProgressComponentPayload(
        'get_study_planner',
        plannerJson(),
      );
      expect(payload, isNotNull);

      final validation = GenerativeUiRegistry.validate(payload!);
      expect(validation.errors, isEmpty);
      final component = validation.component!;
      expect(component.kind, GeneratedComponentKind.studyProgress);
      expect(component.arguments['total_earned'], 45.0);
      expect(component.arguments['total_required'], 60.0);
      expect(component.body, '45 / 60 ECTS');
    });

    test('empty modules and non-planner tools yield no card', () {
      expect(
        studyProgressComponentPayload(
          'get_study_planner',
          plannerJson(withModules: false),
        ),
        isNull,
      );
      expect(
        componentPayloadForTool('get_deadlines', plannerJson()),
        isNull,
      );
    });
  });

  group('mensaMenuComponentPayload', () {
    String mensaJson({bool withData = true}) {
      return jsonEncode(<String, Object?>{
        'state': 'fresh',
        'data': withData
            ? <Map<String, Object?>>[
                <String, Object?>{
                  'id': 'wilhelm:1',
                  'canteen': 'Mensa Wilhelmstraße',
                  'date': '2026-07-22',
                  'line': 'Line 1',
                  'items': <String>['Gemüse-Lasagne', 'Salat'],
                  'dietary_markers': <String>['Vegetarisch'],
                  'student_price': '3,20 €',
                },
              ]
            : <Map<String, Object?>>[],
      });
    }

    test('builds a mensa_menu card from get_mensa_options output', () {
      final payload = mensaMenuComponentPayload('get_mensa_options', mensaJson());
      expect(payload, isNotNull);

      final validation = GenerativeUiRegistry.validate(payload!);
      expect(validation.errors, isEmpty);
      final component = validation.component!;
      expect(component.kind, GeneratedComponentKind.mensaMenu);
      expect(component.title, 'Mensa Wilhelmstraße');

      final options = component.arguments['options'] as List<Object?>;
      final first = options.first as Map<Object?, Object?>;
      expect(first['line'], 'Line 1');
      expect(first['items'], <String>['Gemüse-Lasagne', 'Salat']);
      expect(first['markers'], <String>['Vegetarisch']);
      expect(first['price'], '3,20 €');
    });

    test('empty data and non-mensa tools yield no card', () {
      expect(
        mensaMenuComponentPayload('get_mensa_options', mensaJson(withData: false)),
        isNull,
      );
      expect(componentPayloadForTool('search_talks', mensaJson()), isNull);
    });
  });

  group('campusLocationsComponentPayload', () {
    String locationsJson({bool withData = true}) {
      return jsonEncode(<String, Object?>{
        'state': 'fresh',
        'data': withData
            ? <Map<String, Object?>>[
                <String, Object?>{
                  'id': 'nominatim:48.529600,9.059600',
                  'name': 'Universitätsbibliothek Tübingen',
                  'address': 'Wilhelmstraße 32, 72074 Tübingen',
                  'category': 'library',
                  'latitude': 48.5296,
                  'longitude': 9.0596,
                },
              ]
            : <Map<String, Object?>>[],
      });
    }

    test('builds a campus_locations card keeping coordinates', () {
      final payload = campusLocationsComponentPayload(
        'search_campus_locations',
        locationsJson(),
      );
      expect(payload, isNotNull);

      final validation = GenerativeUiRegistry.validate(payload!);
      expect(validation.errors, isEmpty);
      final component = validation.component!;
      expect(component.kind, GeneratedComponentKind.campusLocations);

      final locations = component.arguments['locations'] as List<Object?>;
      final first = locations.first as Map<Object?, Object?>;
      expect(first['name'], 'Universitätsbibliothek Tübingen');
      expect(first['latitude'], 48.5296);
      expect(first['longitude'], 9.0596);
    });

    test('empty data and non-location tools yield no card', () {
      expect(
        campusLocationsComponentPayload(
          'search_campus_locations',
          locationsJson(withData: false),
        ),
        isNull,
      );
      expect(componentPayloadForTool('get_mensa_options', locationsJson()), isNull);
    });
  });

  group('scheduleAgendaComponentPayload', () {
    String scheduleJson({bool withEvents = true}) {
      return jsonEncode(<String, Object?>{
        'source_term': 'WS 2026/27',
        'refreshed_at': '2026-12-08T09:00:00.000Z',
        'events': withEvents
            ? <Map<String, Object?>>[
                <String, Object?>{
                  'title': 'Machine Learning',
                  'start': '2026-12-09T10:15:00',
                  'end': '2026-12-09T11:45:00',
                  'location': 'Hörsaal 21',
                },
              ]
            : <Map<String, Object?>>[],
      });
    }

    test('builds a schedule_agenda card from get_schedule output', () {
      final payload = scheduleAgendaComponentPayload(
        'get_schedule',
        scheduleJson(),
      );
      expect(payload, isNotNull);

      final validation = GenerativeUiRegistry.validate(payload!);
      expect(validation.errors, isEmpty);
      final component = validation.component!;
      expect(component.kind, GeneratedComponentKind.scheduleAgenda);
      expect(component.title, 'Schedule · WS 2026/27');

      final events = component.arguments['events'] as List<Object?>;
      final first = events.first as Map<Object?, Object?>;
      expect(first['title'], 'Machine Learning');
      expect(first['location'], 'Hörsaal 21');
    });

    test('the prose "not synced" fallback does not produce a card', () {
      expect(
        scheduleAgendaComponentPayload(
          'get_schedule',
          'No timetable has been synced yet.',
        ),
        isNull,
      );
      expect(
        scheduleAgendaComponentPayload('get_schedule', scheduleJson(withEvents: false)),
        isNull,
      );
      expect(componentPayloadForTool('get_deadlines', scheduleJson()), isNull);
    });
  });
}
