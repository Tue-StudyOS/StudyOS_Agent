import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/talks_client.dart';
import 'package:studyos_agent/src/talks_repository.dart';

void main() {
  test(
    'repository coalesces concurrent requests and reuses its cache',
    () async {
      final response = Completer<http.Response>();
      var requests = 0;
      final repository = TalksRepository(
        client: TalksClient(
          httpClient: MockClient((_) {
            requests++;
            return response.future;
          }),
        ),
      );
      addTearDown(repository.dispose);

      final first = repository.load();
      final second = repository.load();
      expect(identical(first, second), isTrue);
      response.complete(_talksResponse());

      expect(await first, hasLength(1));
      expect(await repository.load(), hasLength(1));
      expect(requests, 1);
    },
  );

  test('force refresh bypasses the talks cache', () async {
    var requests = 0;
    final repository = TalksRepository(
      client: TalksClient(
        httpClient: MockClient((_) async {
          requests++;
          return _talksResponse();
        }),
      ),
    );
    addTearDown(repository.dispose);

    await repository.load();
    await repository.load(refresh: true);

    expect(requests, 2);
  });

  test('disposed repository rejects new loads', () async {
    final repository = TalksRepository(
      client: TalksClient(
        httpClient: MockClient((_) async => _talksResponse()),
      ),
    );
    repository.dispose();

    await expectLater(repository.load(), throwsStateError);
  });
}

http.Response _talksResponse() => http.Response(
  jsonEncode(<String, Object?>{
    'talks': <Object?>[
      <String, Object?>{
        'id': 1,
        'title': 'Reliable Agents',
        'timestamp': '2026-07-20T10:00:00',
        'disabled': false,
        'tags': <Object?>[],
      },
    ],
  }),
  200,
);
