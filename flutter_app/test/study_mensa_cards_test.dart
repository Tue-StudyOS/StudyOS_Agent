import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/widgets/mensa_card.dart';
import 'package:studyos_agent/src/widgets/study_progress_card.dart';

void main() {
  GeneratedUiComponent componentOf(String type) {
    final payload = generativeUiFixturePayloads.firstWhere(
      (payload) => payload['type'] == type,
    );
    return GenerativeUiRegistry.validate(payload).component!;
  }

  group('StudyProgressCard', () {
    testWidgets('renders an overall bar and per-module rows', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudyProgressCard(component: componentOf('study_progress')),
          ),
        ),
      );

      expect(find.text('M.Sc. Machine Learning'), findsOneWidget);
      expect(find.textContaining('Overall · 78 / 120 ECTS'), findsOneWidget);
      expect(find.textContaining('Core Machine Learning'), findsOneWidget);
      // One overall bar + three module bars.
      expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
    });
  });

  group('MensaCard', () {
    testWidgets('renders menu lines with items, price and markers', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MensaCard(component: componentOf('mensa_menu'))),
        ),
      );

      expect(find.text('Mensa Wilhelmstraße'), findsOneWidget);
      expect(find.text('Line 1'), findsOneWidget);
      expect(find.text('Gemüse-Lasagne, Blattsalat'), findsOneWidget);
      expect(find.text('3,20 €'), findsOneWidget);
      expect(find.text('Vegetarisch'), findsOneWidget);
    });
  });
}
