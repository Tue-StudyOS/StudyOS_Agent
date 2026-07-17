import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyos_agent/src/feedback_client.dart';
import 'package:studyos_agent/src/feedback_token_store.dart';

void main() {
  test('submit bootstraps an installation and stores only its token', () async {
    final requests = <http.Request>[];
    final tokenStore = _MemoryTokenStore();
    final client = FeedbackClient(
      baseUrl: 'https://feedback.studyos.test',
      tokenStore: tokenStore,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/v1/installations') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'installation_token': _newToken,
              'token_type': 'bearer',
            }),
            201,
          );
        }
        return http.Response(_submissionJson, 200);
      }),
    );

    final feedback = await client.submit(
      courseId: _courseId,
      rating: 4,
      comment: '  Useful, but needs clearer sources.  ',
    );

    expect(requests.map((item) => item.url.path), <String>[
      '/v1/installations',
      '/v1/courses/$_courseId/feedback/mine',
    ]);
    expect(requests.last.headers['Authorization'], 'Bearer $_newToken');
    expect(requests.last.body, contains('Useful, but needs clearer sources.'));
    expect(tokenStore.token, _newToken);
    expect(feedback.rating, 4);
    expect(feedback.commentIsPending, isTrue);
  });

  test('existing installation token is reused for updates', () async {
    var requestCount = 0;
    final client = FeedbackClient(
      baseUrl: 'https://feedback.studyos.test',
      tokenStore: _MemoryTokenStore(
        'saved-installation-token-that-is-long-enough',
      ),
      httpClient: MockClient((request) async {
        requestCount += 1;
        expect(
          request.headers['Authorization'],
          'Bearer saved-installation-token-that-is-long-enough',
        );
        return http.Response(_submissionJson, 200);
      }),
    );

    await client.submit(courseId: _courseId, rating: 5);

    expect(requestCount, 1);
  });

  test(
    'stale installation token is replaced once after unauthorized',
    () async {
      final tokenStore = _MemoryTokenStore(
        'stale-installation-token-that-is-long-enough',
      );
      var putCount = 0;
      final client = FeedbackClient(
        baseUrl: 'https://feedback.studyos.test',
        tokenStore: tokenStore,
        httpClient: MockClient((request) async {
          if (request.method == 'PUT') {
            putCount += 1;
            return putCount == 1
                ? http.Response('{"detail":"invalid bearer token"}', 401)
                : http.Response(_submissionJson, 200);
          }
          expect(request.url.path, '/v1/installations');
          return http.Response(
            jsonEncode(<String, Object?>{
              'installation_token': _newToken,
              'token_type': 'bearer',
            }),
            201,
          );
        }),
      );

      await client.submit(courseId: _courseId, rating: 4);

      expect(putCount, 2);
      expect(tokenStore.token, _newToken);
    },
  );

  test('public response parses aggregate and published comments', () async {
    final client = FeedbackClient(
      baseUrl: 'https://feedback.studyos.test',
      tokenStore: _MemoryTokenStore(),
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(<String, Object?>{
            'course_id': _courseId,
            'course_number': 'INFM1234',
            'rating': <String, Object?>{'count': 2, 'average': 4.5},
            'comments': <Object?>[
              <String, Object?>{
                'id': 'feedback-1',
                'rating': 4,
                'comment': 'Clear and useful',
                'published_at': '2026-07-16T16:00:00Z',
              },
            ],
          }),
          200,
        ),
      ),
    );

    final snapshot = await client.loadPublic(courseId: _courseId);

    expect(snapshot.ratingCount, 2);
    expect(snapshot.averageRating, 4.5);
    expect(snapshot.comments.single.comment, 'Clear and useful');
  });

  test('delete and report use the stored installation identity', () async {
    final requests = <http.Request>[];
    final client = FeedbackClient(
      baseUrl: 'https://feedback.studyos.test',
      tokenStore: _MemoryTokenStore(
        'saved-installation-token-that-is-long-enough',
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        return request.method == 'DELETE'
            ? http.Response('', 204)
            : http.Response('{"status":"recorded"}', 201);
      }),
    );

    await client.report(
      courseId: _courseId,
      feedbackId: 'feedback-1',
      reason: 'spam',
    );
    await client.deleteOwn(courseId: _courseId);

    expect(
      requests.first.url.path,
      '/v1/courses/$_courseId/feedback/feedback-1/reports',
    );
    expect(requests.first.body, contains('spam'));
    expect(requests.last.method, 'DELETE');
    expect(
      requests.every(
        (request) =>
            request.headers['Authorization'] ==
            'Bearer saved-installation-token-that-is-long-enough',
      ),
      isTrue,
    );
  });

  test('loadOwn does not create an installation just to read', () async {
    final client = FeedbackClient(
      baseUrl: 'https://feedback.studyos.test',
      tokenStore: _MemoryTokenStore(),
      httpClient: MockClient((_) async => throw StateError('not expected')),
    );

    expect(await client.loadOwn(courseId: _courseId), isNull);
  });

  test('rejects insecure non-loopback endpoint and invalid ratings', () async {
    final insecure = FeedbackClient(
      baseUrl: 'http://feedback.example.com',
      tokenStore: _MemoryTokenStore(),
    );
    final local = FeedbackClient(
      baseUrl: 'http://localhost:8080',
      tokenStore: _MemoryTokenStore(),
    );

    expect(insecure.isConfigured, isFalse);
    expect(local.isConfigured, isTrue);
    expect(
      () => local.submit(courseId: _courseId, rating: 0),
      throwsA(isA<FeedbackException>()),
    );
  });

  test('surfaces bounded API error details', () async {
    final client = FeedbackClient(
      baseUrl: 'https://feedback.studyos.test',
      tokenStore: _MemoryTokenStore(
        'saved-installation-token-that-is-long-enough',
      ),
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(<String, Object?>{'detail': 'Rating is rate limited.'}),
          429,
        ),
      ),
    );

    expect(
      () => client.submit(courseId: _courseId, rating: 3),
      throwsA(
        isA<FeedbackException>().having(
          (error) => error.message,
          'message',
          'Rating is rate limited.',
        ),
      ),
    );
  });

  test('maps a stalled request to a feedback timeout', () async {
    final client = FeedbackClient(
      baseUrl: 'https://feedback.studyos.test',
      tokenStore: _MemoryTokenStore(),
      requestTimeout: const Duration(milliseconds: 1),
      httpClient: MockClient((_) => Completer<http.Response>().future),
    );

    expect(
      () => client.loadPublic(courseId: _courseId),
      throwsA(
        isA<FeedbackException>().having(
          (error) => error.message,
          'message',
          'The feedback service timed out.',
        ),
      ),
    );
  });

  test('maps transport failures to an unreachable error', () async {
    final client = FeedbackClient(
      baseUrl: 'https://feedback.studyos.test',
      tokenStore: _MemoryTokenStore(),
      httpClient: MockClient(
        (_) async => throw http.ClientException('offline'),
      ),
    );

    expect(
      () => client.loadPublic(courseId: _courseId),
      throwsA(
        isA<FeedbackException>().having(
          (error) => error.message,
          'message',
          'The feedback service is unreachable.',
        ),
      ),
    );
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

final String _submissionJson = jsonEncode(<String, Object?>{
  'id': 'feedback-1',
  'course_id': _courseId,
  'rating': 4,
  'comment': 'Useful, but needs clearer sources.',
  'comment_state': 'pending',
  'created_at': '2026-07-16T16:00:00Z',
  'updated_at': '2026-07-16T16:00:00Z',
});

const String _newToken = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _courseId = 'SU5GTTEyMzQ';
