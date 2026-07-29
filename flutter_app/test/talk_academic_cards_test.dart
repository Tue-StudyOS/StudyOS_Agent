import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/widgets/academic_status_card.dart';
import 'package:studyos_agent/src/widgets/talk_card.dart';

void main() {
  GeneratedUiComponent componentOf(String type) {
    final payload = generativeUiFixturePayloads.firstWhere(
      (payload) => payload['type'] == type,
    );
    return GenerativeUiRegistry.validate(payload).component!;
  }

  group('TalkCard', () {
    testWidgets('renders talks with speaker and location', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TalkCard(component: componentOf('talk_list'))),
        ),
      );

      expect(find.text('2 upcoming talks'), findsOneWidget);
      expect(
        find.text('Foundation models for scientific discovery'),
        findsOneWidget,
      );
      expect(find.textContaining('Dr. Amelie Roth'), findsOneWidget);
    });

    testWidgets('Remind me emits a ReminderComponentAction at the talk time', (
      tester,
    ) async {
      final actions = <GeneratedComponentAction>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TalkCard(
              component: componentOf('talk_list'),
              onAction: actions.add,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Remind me').first);
      await tester.pump();

      expect(actions, hasLength(1));
      final action = actions.single as ReminderComponentAction;
      expect(action.title, 'Foundation models for scientific discovery');
      expect(
        action.dueAt.isAtSameMomentAs(
          DateTime.parse('2026-12-09T16:15:00.000Z'),
        ),
        isTrue,
      );
    });
  });

  group('AcademicStatusCard', () {
    testWidgets('groups entries by category with status badges', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AcademicStatusCard(component: componentOf('academic_status')),
          ),
        ),
      );

      expect(find.text('Academic status · WS 2026/27'), findsOneWidget);
      // Category headers are upper-cased; two exams share one "EXAMS" header.
      expect(find.text('EXAMS'), findsOneWidget);
      expect(find.text('COURSES'), findsOneWidget);
      expect(find.text('Machine Learning — written exam'), findsOneWidget);
      expect(find.text('Passed (1.7)'), findsOneWidget);
    });
  });
}
