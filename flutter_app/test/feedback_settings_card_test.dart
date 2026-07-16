import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyos_agent/src/feedback_client.dart';
import 'package:studyos_agent/src/feedback_token_store.dart';
import 'package:studyos_agent/src/widgets/feedback_settings_card.dart';

void main() {
  testWidgets('submits stars and comment through the feedback API', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final client = FeedbackClient(
      baseUrl: 'https://feedback.studyos.test',
      tokenStore: _MemoryTokenStore(),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/v1/installations') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'installation_token': _token,
              'token_type': 'bearer',
            }),
            201,
          );
        }
        if (request.method == 'PUT') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'id': 'feedback-1',
              'service_id': 'studyos-agent',
              'rating': 4,
              'comment': 'Helpful service catalog',
              'comment_state': 'pending',
              'created_at': '2026-07-16T16:00:00Z',
              'updated_at': '2026-07-16T16:00:00Z',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode(<String, Object?>{
            'service_id': 'studyos-agent',
            'rating': <String, Object?>{
              'count': request.method == 'GET' && requests.length > 3 ? 1 : 0,
              'average': requests.length > 3 ? 4.0 : null,
            },
            'comments': <Object?>[],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FeedbackSettingsCard(client: client),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('4 stars'));
    await tester.enterText(find.byType(TextField), 'Helpful service catalog');
    await tester.tap(find.text('Send feedback'));
    await tester.pumpAndSettle();

    expect(find.text('Update feedback'), findsOneWidget);
    expect(
      find.text('Your comment is awaiting moderator review.'),
      findsOneWidget,
    );
    final update = requests.singleWhere((request) => request.method == 'PUT');
    expect(update.body, contains('"rating":4'));
    expect(update.body, contains('Helpful service catalog'));
  });

  testWidgets('shows an explicit unavailable state without an endpoint', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedbackSettingsCard(
            client: FeedbackClient(
              baseUrl: '',
              tokenStore: _MemoryTokenStore(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Feedback is unavailable'), findsOneWidget);
    expect(find.text('Send feedback'), findsNothing);
  });

  testWidgets('shows the moderator state of an existing comment', (
    tester,
  ) async {
    final client = FeedbackClient(
      baseUrl: 'https://feedback.studyos.test',
      tokenStore: _MemoryTokenStore(_token),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/public')) {
          return http.Response(
            '{"service_id":"studyos-agent","rating":{"count":1,"average":2.0},"comments":[]}',
            200,
          );
        }
        return http.Response(
          jsonEncode(<String, Object?>{
            'id': 'feedback-1',
            'service_id': 'studyos-agent',
            'rating': 2,
            'comment': 'Needs work',
            'comment_state': 'rejected',
            'created_at': '2026-07-16T16:00:00Z',
            'updated_at': '2026-07-16T16:00:00Z',
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FeedbackSettingsCard(client: client)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Your comment was not published after review.'),
      findsOneWidget,
    );
    expect(find.text('Update feedback'), findsOneWidget);
  });

  testWidgets('confirms and deletes owned feedback', (tester) async {
    final requests = <http.Request>[];
    var deleted = false;
    final client = FeedbackClient(
      baseUrl: 'https://feedback.studyos.test',
      tokenStore: _MemoryTokenStore(_token),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'DELETE') {
          deleted = true;
          return http.Response('', 204);
        }
        if (request.url.path.endsWith('/public')) {
          return http.Response(
            '{"service_id":"studyos-agent","rating":{"count":${deleted ? 0 : 1},"average":${deleted ? 'null' : '5.0'}},"comments":[]}',
            200,
          );
        }
        return http.Response(
          jsonEncode(<String, Object?>{
            'id': 'feedback-1',
            'service_id': 'studyos-agent',
            'rating': 5,
            'comment': null,
            'comment_state': 'none',
            'created_at': '2026-07-16T16:00:00Z',
            'updated_at': '2026-07-16T16:00:00Z',
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FeedbackSettingsCard(client: client)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete my feedback'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(requests.any((request) => request.method == 'DELETE'), isTrue);
    expect(find.text('Send feedback'), findsOneWidget);
    expect(find.text('No ratings yet.'), findsOneWidget);
  });

  testWidgets('reports a published comment with a reason', (tester) async {
    final requests = <http.Request>[];
    final client = FeedbackClient(
      baseUrl: 'https://feedback.studyos.test',
      tokenStore: _MemoryTokenStore(_token),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          return http.Response('{"status":"recorded"}', 201);
        }
        if (request.url.path.endsWith('/mine')) {
          return http.Response('{"detail":"feedback not found"}', 404);
        }
        return http.Response(
          jsonEncode(<String, Object?>{
            'service_id': 'studyos-agent',
            'rating': <String, Object?>{'count': 1, 'average': 1.0},
            'comments': <Object?>[
              <String, Object?>{
                'id': 'feedback-other',
                'rating': 1,
                'comment': 'Contains personal details',
                'published_at': '2026-07-16T16:00:00Z',
              },
            ],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FeedbackSettingsCard(client: client),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Report comment'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'personal data');
    await tester.tap(find.widgetWithText(FilledButton, 'Report'));
    await tester.pumpAndSettle();

    final report = requests.singleWhere((request) => request.method == 'POST');
    expect(report.url.path, contains('/feedback-other/reports'));
    expect(report.body, contains('personal data'));
    expect(find.text('Comment reported for review.'), findsOneWidget);
  });
}

class _MemoryTokenStore implements FeedbackTokenStore {
  _MemoryTokenStore([this.token]);

  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}

const String _token = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
