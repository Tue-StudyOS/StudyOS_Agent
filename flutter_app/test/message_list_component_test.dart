import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/widgets/mail_triage_card.dart';
import 'package:studyos_agent/src/widgets/message_list.dart';

void main() {
  Map<String, Object?> mailPayload() {
    return generativeUiFixturePayloads.firstWhere(
      (payload) => payload['type'] == 'mail_list',
    );
  }

  Widget host(List<ChatMessage> messages) {
    return MaterialApp(
      home: Scaffold(
        body: MessageList(
          messages: messages,
          compact: false,
          controller: ScrollController(),
        ),
      ),
    );
  }

  testWidgets('assistant message renders its component beneath the text', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(<ChatMessage>[
        ChatMessage(
          author: 'StudyOS Agent',
          text: 'Here are your recent emails:',
          isUser: false,
          component: mailPayload(),
        ),
      ]),
    );

    expect(find.text('Here are your recent emails:'), findsOneWidget);
    expect(find.byType(MailTriageCard), findsOneWidget);

    // The card sits below the lead-in text in the vertical layout.
    final textY = tester.getTopLeft(find.text('Here are your recent emails:')).dy;
    final cardY = tester.getTopLeft(find.byType(MailTriageCard)).dy;
    expect(cardY, greaterThan(textY));
  });

  testWidgets('tool trace rows never render the mail card', (tester) async {
    await tester.pumpWidget(
      host(<ChatMessage>[
        ChatMessage.toolTrace(
          toolName: 'get_recent_mail',
          status: 'done',
          summary: 'Checked recent mail.',
        ),
      ]),
    );

    expect(find.byType(MailTriageCard), findsNothing);
    expect(find.text('get_recent_mail'), findsOneWidget);
  });

  testWidgets('drops a restated list beneath the card, keeping the lead-in', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(<ChatMessage>[
        ChatMessage(
          author: 'StudyOS Agent',
          text:
              'Here are your recent emails:\n'
              '- ML exercise sheet 7 from Prof. Weber\n'
              '- Room change from Studierendensekretariat',
          isUser: false,
          component: mailPayload(),
        ),
      ]),
    );

    expect(find.byType(MailTriageCard), findsOneWidget);
    expect(find.text('Here are your recent emails:'), findsOneWidget);
    // The restated bullet lines are dropped — the card already shows them.
    expect(
      find.textContaining('from Prof. Weber', findRichText: true),
      findsNothing,
    );
  });
}
