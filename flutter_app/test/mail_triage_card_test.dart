import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/widgets/mail_triage_card.dart';

void main() {
  GeneratedUiComponent mailComponent() {
    final payload = generativeUiFixturePayloads.firstWhere(
      (payload) => payload['type'] == 'mail_list',
    );
    return GenerativeUiRegistry.validate(payload).component!;
  }

  testWidgets('renders one row per message with sender and subject', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MailTriageCard(component: mailComponent())),
      ),
    );

    expect(find.text('INBOX · 2 unread'), findsOneWidget);
    expect(find.text('Prof. Dr. Weber'), findsOneWidget);
    expect(
      find.text('ML exercise sheet 7 — submission Friday'),
      findsOneWidget,
    );
    // Official broadcast badge on the approved message.
    expect(find.text('Official'), findsOneWidget);
  });

  testWidgets('action buttons submit a non-sending prompt via onAction', (
    tester,
  ) async {
    final actions = <GeneratedComponentAction>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MailTriageCard(
            component: mailComponent(),
            onAction: actions.add,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Draft reply').first);
    await tester.pump();

    expect(actions, hasLength(1));
    final action = actions.single as PromptComponentAction;
    expect(action.prompt, contains('ML exercise sheet 7'));
    expect(action.prompt, contains('mail uid 4821'));
    // A reply is side-effecting, so the prompt must forbid auto-sending.
    expect(action.prompt, contains('do not send'));
  });

  testWidgets('omits action buttons when onAction is null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MailTriageCard(component: mailComponent())),
      ),
    );

    expect(find.text('Summarize'), findsNothing);
    expect(find.text('Draft reply'), findsNothing);
  });
}
