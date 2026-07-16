import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyos_agent/src/studyos_theme.dart';
import 'package:studyos_agent/src/talks_client.dart';
import 'package:studyos_agent/src/talks_repository.dart';
import 'package:studyos_agent/src/views/talks_view.dart';

void main() {
  testWidgets('talks view lists and filters upcoming talks', (tester) async {
    final client = TalksClient(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(<String, Object?>{
            'talks': <Object?>[
              <String, Object?>{
                'id': 1,
                'title': 'AI interfaces',
                'timestamp': '2026-07-14T10:15:00',
                'disabled': false,
                'location': 'AI Center',
                'speaker_name': 'Ada Lovelace',
                'tags': <Object?>[],
              },
              <String, Object?>{
                'id': 2,
                'title': 'Cognitive science colloquium',
                'timestamp': '2026-07-15T12:00:00',
                'disabled': false,
                'location': 'Kupferbau',
                'speaker_name': 'Grace Hopper',
                'tags': <Object?>[],
              },
            ],
          }),
          200,
        ),
      ),
    );
    final repository = TalksRepository(client: client);
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudyOsTheme(),
        home: TalksView(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tübingen Talks'), findsOneWidget);
    expect(find.text('2 upcoming talks'), findsOneWidget);
    expect(find.text('AI interfaces'), findsOneWidget);
    expect(find.text('Cognitive science colloquium'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('talks-search')),
      'Ada',
    );
    await tester.pump();

    expect(find.text('1 upcoming talk'), findsOneWidget);
    expect(find.text('AI interfaces'), findsOneWidget);
    expect(find.text('Cognitive science colloquium'), findsNothing);
  });
}
