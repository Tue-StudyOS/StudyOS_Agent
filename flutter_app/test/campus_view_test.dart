import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyos_agent/src/campus_client.dart';
import 'package:studyos_agent/src/studyos_theme.dart';
import 'package:studyos_agent/src/views/campus_view.dart';

void main() {
  testWidgets('Campus hides menus outside the current week', (tester) async {
    final client = CampusClient(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object?>{
            '611': <String, Object?>{
              'canteen': 'Mensa Morgenstelle',
              'menus': <Object?>[
                <String, Object?>{
                  'id': 'current-week',
                  'menuLine': 'Tagesmenü vegan',
                  'menuDate': '2026-06-30',
                  'menu': <String>['Bandnudeln'],
                  'icons': <String>['vegan'],
                  'studentPrice': '3,70',
                },
              ],
            },
            '621': <String, Object?>{
              'canteen': 'Cafeteria Wilhelmstraße',
              'menus': <Object?>[
                <String, Object?>{
                  'id': 'next-week',
                  'menuLine': 'Angebot des Tages',
                  'menuDate': '2026-07-07',
                  'menu': <String>['Hausgemachte Pasta'],
                  'studentPrice': '5,20',
                },
              ],
            },
          }),
          200,
          request: request,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudyOsTheme(),
        home: Scaffold(
          body: CampusView(
            profile: null,
            client: client,
            today: DateTime(2026, 7, 2),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This week\'s Mensa menus for Tübingen.'), findsOneWidget);
    expect(find.text('Mensa Morgenstelle'), findsOneWidget);
    expect(find.textContaining('2026-06-30'), findsOneWidget);
    expect(find.textContaining('Bandnudeln'), findsOneWidget);
    expect(find.text('Cafeteria Wilhelmstraße'), findsNothing);
    expect(find.textContaining('2026-07-07'), findsNothing);
    expect(find.text('Hausgemachte Pasta'), findsNothing);
  });
}
