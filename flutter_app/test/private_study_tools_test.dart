import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyos_agent/src/portal_http_session.dart';
import 'package:studyos_agent/src/private_study_capabilities.dart';
import 'package:studyos_agent/src/private_study_clients.dart';
import 'package:studyos_agent/src/private_study_models.dart';
import 'package:studyos_agent/src/private_study_parsers.dart';
import 'package:studyos_agent/src/private_study_tools.dart';

void main() {
  test('recognizes the current authenticated ILIAS shell', () {
    final response = PortalResponse(
      response: http.Response(
        '<html><nav class="il-maincontrols-metabar"></nav></html>',
        200,
      ),
      url: Uri.parse('https://ovidius.uni-tuebingen.de/ilias.php'),
    );

    expect(isAuthenticatedIliasPage(response), isTrue);
  });

  test('does not accept an ILIAS login page as authenticated', () {
    final response = PortalResponse(
      response: http.Response(
        '<html>Login mit zentraler Universitäts-Kennung</html>',
        200,
      ),
      url: Uri.parse('https://ovidius.uni-tuebingen.de/login.php'),
    );

    expect(isAuthenticatedIliasPage(response), isFalse);
  });

  test('portal form includes a required submit button', () {
    final form = portalForm(
      '''
      <form action="/continue" method="post">
        <input type="hidden" name="csrf" value="safe">
        <button type="submit" name="_eventId_proceed" value="continue">Continue</button>
        <button type="submit" name="_eventId_cancel" value="cancel">Cancel</button>
      </form>
      ''',
      Uri.parse('https://idp.uni-tuebingen.de/flow'),
      requiredFields: const <String>{'_eventId_proceed'},
    );

    expect(form.action.path, '/continue');
    expect(form.payload['_eventId_proceed'], 'continue');
    expect(form.payload['_eventId_cancel'], isNull);
    expect(form.payload['csrf'], 'safe');
  });

  test('SAML handoff submits an IdP proceed button', () async {
    final requests = <http.Request>[];
    final session = PortalHttpSession(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.host == 'idp.uni-tuebingen.de') {
          return http.Response(
            '',
            302,
            headers: <String, String>{
              'location': 'https://ovidius.uni-tuebingen.de/ilias.php',
            },
            request: request,
          );
        }
        return http.Response(
          '<html><nav class="il-maincontrols-metabar"></nav></html>',
          200,
          request: request,
        );
      }),
    );
    final response = await completeSaml(
      PortalResponse(
        response: http.Response('''
          <form action="/continue" method="post">
            <input type="hidden" name="csrf" value="safe">
            <button type="submit" name="_eventId_proceed">Continue</button>
          </form>
          ''', 200),
        url: Uri.parse('https://idp.uni-tuebingen.de/flow'),
      ),
      session,
      isAuthenticated: isAuthenticatedIliasPage,
    );

    expect(response.url.host, 'ovidius.uni-tuebingen.de');
    expect(requests.first.body, contains('_eventId_proceed='));
    session.close();
  });

  test('ILIAS parser preserves hints and normalizes reliable dates', () {
    final tasks = parseIliasTasks(
      _iliasTasksHtml,
      Uri.parse('https://ilias.test/tasks'),
    );

    expect(tasks, hasLength(2));
    expect(tasks.first.title, 'Exercise sheet 4');
    expect(tasks.first.courseTitle, 'Machine Learning');
    expect(tasks.first.dueAt, DateTime.utc(2026, 7, 20, 21, 59));
    expect(tasks.first.url, 'https://ilias.test/exercise/4');
    expect(tasks.last.dueAt, isNull);
    expect(tasks.last.rawDueHint, 'next tutorial');
  });

  test('Moodle parser normalizes actionable calendar events', () {
    final tasks = parseMoodleEvents(
      jsonEncode(<Object?>[
        <String, Object?>{
          'error': false,
          'data': <String, Object?>{
            'events': <Object?>[
              <String, Object?>{
                'id': 42,
                'name': 'Submit report',
                'timesort': 1784584740,
                'formattedtime': 'Monday, 23:59',
                'course': <String, Object?>{'fullname': 'Agentic Systems'},
                'action': <String, Object?>{
                  'url': '/mod/assign/view.php?id=42',
                },
              },
            ],
          },
        },
      ]),
      Uri.parse('https://moodle.test/'),
    );

    expect(tasks, hasLength(1));
    expect(tasks.single.id, '42');
    expect(tasks.single.courseTitle, 'Agentic Systems');
    expect(tasks.single.dueAt, isNotNull);
    expect(tasks.single.actionable, isTrue);
    expect(tasks.single.url, 'https://moodle.test/mod/assign/view.php?id=42');
  });

  test('ILIAS assignment parser includes only confirmed dated entries', () {
    final deadlines = parseIliasAssignments(
      _iliasAssignmentHtml,
      Uri.parse('https://ilias.test/exercise'),
    );

    expect(deadlines, hasLength(1));
    expect(deadlines.single.title, 'Final report');
    expect(deadlines.single.dueAt, DateTime.utc(2026, 7, 25, 21, 59));
    expect(deadlines.single.requirement, 'Mandatory');
  });

  test(
    'get_tasks returns healthy source with bounded partial failure',
    () async {
      var moodleCalls = 0;
      final capability = PrivateStudyCapability(
        profileProvider: () => null,
        credentialsProvider: () async =>
            const PortalCredentials('student', 'secret'),
        iliasFactory: (_, _) =>
            _FakeIlias(tasksError: const PortalException('offline')),
        moodleFactory: (_, _) => _FakeMoodle(
          onFetch: () {
            moodleCalls += 1;
            return <PortalTask>[
              _task(
                StudyPortalSource.moodle,
                'later',
                DateTime.utc(2026, 7, 22),
              ),
              _task(
                StudyPortalSource.moodle,
                'soon',
                DateTime.utc(2026, 7, 20),
              ),
            ];
          },
        ),
        clock: () => DateTime.utc(2026, 7, 17),
      );
      final runner = LivePrivateStudyToolRunner(capability);

      final first = _json(
        await runner.execute(getTasksToolName, '{"limit":1}'),
      );
      final second = _json(
        await runner.execute(getTasksToolName, '{"limit":1}'),
      );

      expect(first['state'], 'fresh');
      expect(_policy(first)['privacy'], 'private_local');
      expect(_data(first), hasLength(1));
      expect(_data(first).single['title'], 'soon');
      expect(
        (first['failures'] as List).single,
        containsPair('source', 'ilias'),
      );
      expect(first['message'], contains('ilias: offline'));
      expect(jsonEncode(first), isNot(contains('secret')));
      expect(
        moodleCalls,
        1,
        reason: 'the second call should use the TTL cache',
      );
      expect(second, first);
    },
  );

  test(
    'get_deadlines filters window and deduplicates confirmed dates',
    () async {
      final inside = PortalDeadline(
        source: StudyPortalSource.ilias,
        id: 'one',
        title: 'Sheet',
        dueAt: DateTime.utc(2026, 7, 20),
        url: 'https://ilias.test/sheet',
        dueHint: '20.07.2026',
      );
      final capability = PrivateStudyCapability(
        profileProvider: () => null,
        credentialsProvider: () async =>
            const PortalCredentials('student', 'secret'),
        iliasFactory: (_, _) => _FakeIlias(
          deadlines: <PortalDeadline>[
            inside,
            inside,
            PortalDeadline(
              source: StudyPortalSource.ilias,
              id: 'outside',
              title: 'Old sheet',
              dueAt: DateTime.utc(2026, 6, 1),
              url: 'https://ilias.test/old',
            ),
          ],
        ),
        moodleFactory: (_, _) =>
            _FakeMoodle(onFetch: () => const <PortalTask>[]),
        clock: () => DateTime.utc(2026, 7, 17),
      );
      final result = _json(
        await LivePrivateStudyToolRunner(
          capability,
        ).execute(getDeadlinesToolName, '{"days":30,"sources":["ilias"]}'),
      );

      expect(result['state'], 'fresh');
      expect(_data(result), hasLength(1));
      expect(_data(result).single['dueHint'], '20.07.2026');
    },
  );

  test('private tools distinguish missing local authentication', () async {
    final capability = PrivateStudyCapability(
      profileProvider: () => null,
      credentialsProvider: () async => null,
    );
    final result = _json(
      await LivePrivateStudyToolRunner(
        capability,
      ).execute(getTasksToolName, '{}'),
    );

    expect(result['state'], 'authenticationRequired');
    expect(result['message'], contains('Sign in locally'));
  });

  test('private tools preserve bounded SAML failure details', () async {
    final capability = PrivateStudyCapability(
      profileProvider: () => null,
      credentialsProvider: () async =>
          const PortalCredentials('student', 'secret'),
      iliasFactory: (_, _) => _FakeIlias(
        tasksError: const PortalAuthenticationException(
          'Could not complete the university SAML handoff.',
        ),
      ),
      moodleFactory: (_, _) => _FakeMoodle(onFetch: () => const <PortalTask>[]),
    );
    final result = _json(
      await LivePrivateStudyToolRunner(
        capability,
      ).execute(getTasksToolName, '{"sources":["ilias"]}'),
    );

    expect(result['state'], 'authenticationRequired');
    expect(
      (result['failures'] as List).single,
      containsPair(
        'message',
        'authentication required: Could not complete the university SAML handoff.',
      ),
    );
    expect(jsonEncode(result), isNot(contains('secret')));
  });

  test('private tools serve stale local data after refresh failure', () async {
    var now = DateTime.utc(2026, 7, 17);
    var calls = 0;
    final capability = PrivateStudyCapability(
      profileProvider: () => null,
      credentialsProvider: () async =>
          const PortalCredentials('student', 'secret'),
      iliasFactory: (_, _) => _FakeIlias(
        onTasks: () {
          calls += 1;
          if (calls > 1) throw const PortalException('offline');
          return <PortalTask>[
            _task(StudyPortalSource.ilias, 'cached', DateTime.utc(2026, 7, 20)),
          ];
        },
      ),
      moodleFactory: (_, _) => _FakeMoodle(onFetch: () => const <PortalTask>[]),
      clock: () => now,
      ttl: const Duration(minutes: 1),
    );
    final runner = LivePrivateStudyToolRunner(capability);

    await runner.execute(getTasksToolName, '{"sources":["ilias"],"limit":10}');
    now = now.add(const Duration(minutes: 2));
    final stale = _json(
      await runner.execute(
        getTasksToolName,
        '{"sources":["ilias"],"limit":10}',
      ),
    );

    expect(stale['state'], 'stale');
    expect(_data(stale).single['title'], 'cached');
    expect((stale['failures'] as List).single, containsPair('source', 'ilias'));
  });

  test('tool output strips session-shaped URL parameters', () {
    expect(
      safePortalTarget(
        'https://moodle.test/mod/assign?id=42&sesskey=secret&token=hidden',
      ),
      'https://moodle.test/mod/assign?id=42',
    );
  });

  test('portal session scopes cookies to the issuing host', () async {
    final requests = <http.Request>[];
    final session = PortalHttpSession(
      allowedHostSuffix: 'test',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          'ok',
          200,
          headers: request.url.host == 'idp.test'
              ? <String, String>{'set-cookie': 'idp_session=private; Secure'}
              : const <String, String>{},
          request: request,
        );
      }),
    );

    await session.get(Uri.parse('https://idp.test/login'));
    await session.get(Uri.parse('https://moodle.test/home'));

    expect(requests.first.headers['Cookie'], isNull);
    expect(requests.last.headers['Cookie'], isNull);
    session.close();
  });

  test('portal session rejects untrusted redirects before sending', () async {
    final session = PortalHttpSession(
      client: MockClient((_) async => http.Response('unexpected', 200)),
    );

    await expectLater(
      session.get(Uri.parse('https://evil.example/login')),
      throwsA(isA<PortalException>()),
    );
    session.close();
  });
}

class _FakeIlias implements IliasStudySource {
  _FakeIlias({
    this.deadlines = const <PortalDeadline>[],
    this.tasksError,
    this.onTasks,
  });

  final List<PortalDeadline> deadlines;
  final Object? tasksError;
  final List<PortalTask> Function()? onTasks;

  @override
  Future<List<PortalTask>> fetchTasks({required int limit}) async {
    if (tasksError case final error?) throw error;
    return (onTasks?.call() ?? const <PortalTask>[]).take(limit).toList();
  }

  @override
  Future<List<PortalDeadline>> fetchDeadlines({required int scanLimit}) async =>
      deadlines;

  @override
  void close() {}
}

class _FakeMoodle implements MoodleStudySource {
  _FakeMoodle({required this.onFetch});
  final List<PortalTask> Function() onFetch;

  @override
  Future<List<PortalTask>> fetchEvents({
    required int days,
    required int limit,
  }) async => onFetch().take(limit).toList();

  @override
  void close() {}
}

PortalTask _task(StudyPortalSource source, String title, DateTime dueAt) =>
    PortalTask(
      source: source,
      id: title,
      title: title,
      url: 'https://${source.name}.test/$title',
      dueAt: dueAt,
    );

Map<String, Object?> _json(String value) =>
    Map<String, Object?>.from(jsonDecode(value) as Map);

Map<String, Object?> _policy(Map<String, Object?> result) =>
    Map<String, Object?>.from(result['policy'] as Map);

List<Map<String, Object?>> _data(Map<String, Object?> result) =>
    (result['data'] as List)
        .map((item) => Map<String, Object?>.from(item as Map))
        .toList();

const _iliasTasksHtml = '''
<div class="il-item il-std-item">
  <div class="il-item-title"><a href="/exercise/4">Exercise sheet 4</a></div>
  <span class="il-item-property-name">Kurs</span><span class="il-item-property-value">Machine Learning</span>
  <span class="il-item-property-name">Beginn</span><span class="il-item-property-value">17.07.2026, 08:00</span>
  <span class="il-item-property-name">Ende</span><span class="il-item-property-value">20.07.2026, 23:59</span>
</div>
<div class="il-item il-std-item">
  <div class="il-item-title"><a href="/quiz">Quiz</a></div>
  <span class="il-item-property-name">Ende</span><span class="il-item-property-value">next tutorial</span>
</div>
''';

const _iliasAssignmentHtml = '''
<div class="il-item il-std-item">
  <div class="il-item-title"><a href="/assignment/final">Final report</a></div>
  <span class="il-item-property-name">Abgabetermin</span><span class="il-item-property-value">25.07.2026, 23:59</span>
  <span class="il-item-property-name">Anforderung</span><span class="il-item-property-value">Mandatory</span>
</div>
<div class="il-item il-std-item">
  <div class="il-item-title"><a href="/assignment/undated">Optional reading</a></div>
</div>
''';
