import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyos_agent/src/talks_client.dart';

void main() {
  test('talks client decodes and orders upcoming public talks', () async {
    final client = TalksClient(
      httpClient: MockClient((request) async {
        expect(request.url.host, 'talks.tuebingen.ai');
        expect(request.url.path, '/api/talks');
        return http.Response(
          jsonEncode(<String, Object?>{
            'talks': <Object?>[
              <String, Object?>{
                'id': 2,
                'title': 'Later talk',
                'timestamp': '2026-07-16T10:15:00',
                'disabled': false,
                'location': 'Kupferbau',
                'speaker_name': 'Grace Hopper',
                'tags': <Object?>[],
              },
              <String, Object?>{
                'id': 1,
                'title': 'AI interfaces',
                'timestamp': '2026-07-14T10:15:00',
                'disabled': false,
                'location': 'AI Center',
                'speaker_name': 'Ada Lovelace',
                'tags': <Object?>[
                  <String, Object?>{'id': 3, 'name': 'AI'},
                ],
              },
              <String, Object?>{
                'id': 3,
                'title': 'Hidden talk',
                'timestamp': '2026-07-12T10:15:00',
                'disabled': true,
                'tags': <Object?>[],
              },
            ],
          }),
          200,
          request: request,
        );
      }),
    );

    final talks = await client.fetchUpcoming();

    expect(talks.map((talk) => talk.title), <String>[
      'AI interfaces',
      'Later talk',
    ]);
    expect(talks.first.matches('ada'), isTrue);
    expect(talks.first.matches('kupferbau'), isFalse);
    expect(talks.first.sourceUri.host, 'talks.tuebingen.ai');
  });
}
