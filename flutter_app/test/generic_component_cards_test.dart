import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/widgets/deadline_highlight_card.dart';
import 'package:studyos_agent/src/widgets/message_list.dart';
import 'package:studyos_agent/src/widgets/next_action_card.dart';
import 'package:studyos_agent/src/widgets/quick_reply_card.dart';

void main() {
  Map<String, Object?> fixture(String type) {
    return generativeUiFixturePayloads.firstWhere(
      (payload) => payload['type'] == type,
    );
  }

  Widget hostMessages(
    List<ChatMessage> messages, {
    ValueChanged<GeneratedComponentAction>? onAction,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MessageList(
          messages: messages,
          compact: false,
          controller: ScrollController(),
          onComponentAction: onAction,
        ),
      ),
    );
  }

  ChatMessage assistant(String text, Map<String, Object?> component) {
    return ChatMessage(
      author: 'StudyOS Agent',
      text: text,
      isUser: false,
      component: component,
    );
  }

  testWidgets('quick_reply renders and taps dispatch a prompt action', (
    tester,
  ) async {
    GeneratedComponentAction? action;
    await tester.pumpWidget(
      hostMessages(<ChatMessage>[
        assistant('Want a plan?', fixture('quick_reply')),
      ], onAction: (value) => action = value),
    );

    expect(find.byType(QuickReplyCard), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();

    expect(action, isA<PromptComponentAction>());
    expect(
      (action! as PromptComponentAction).prompt,
      'Plan a 45 minute review block around my next lecture.',
    );
  });

  testWidgets('next_action renders its CTA and dispatches it as a prompt', (
    tester,
  ) async {
    GeneratedComponentAction? action;
    await tester.pumpWidget(
      hostMessages(<ChatMessage>[
        assistant('You could:', fixture('next_action')),
      ], onAction: (value) => action = value),
    );

    expect(find.byType(NextActionCard), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Open schedule'));
    await tester.pump();

    expect(action, isA<PromptComponentAction>());
    expect((action! as PromptComponentAction).prompt, 'Open schedule');
  });

  testWidgets('deadline_card renders and offers a reminder action', (
    tester,
  ) async {
    GeneratedComponentAction? action;
    await tester.pumpWidget(
      hostMessages(<ChatMessage>[
        assistant('Heads up:', fixture('deadline_card')),
      ], onAction: (value) => action = value),
    );

    expect(find.byType(DeadlineHighlightCard), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Add reminder'));
    await tester.pump();

    expect(action, isA<ReminderComponentAction>());
  });

  testWidgets('a model-emitted card keeps the full prose answer', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostMessages(<ChatMessage>[
        assistant(
          'Here is a full multi-line answer.\n'
          'It has a second detailed line worth keeping.',
          fixture('quick_reply'),
        ),
      ]),
    );

    // Unlike a tool data-card, the prose under a model card is not trimmed to a
    // lead-in — the second line survives.
    expect(
      find.textContaining('second detailed line', findRichText: true),
      findsOneWidget,
    );
  });
}
