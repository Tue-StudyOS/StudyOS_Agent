import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/studyos_theme.dart';
import 'package:studyos_agent/src/views/chat_view.dart';

void main() {
  testWidgets('suggestions hide after a conversation starts', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _TestShell(
        child: ChatView(
          messages: <ChatMessage>[
            ChatMessage(author: 'You', text: 'Plan study block', isUser: true),
          ],
          inputController: controller,
          isSending: false,
          compactMessages: false,
          onSuggestionSelected: (_) {},
          onSend: () {},
        ),
      ),
    );

    expect(find.text('Summarize today'), findsNothing);
    expect(find.text('Find next lecture'), findsNothing);
    expect(find.text('Plan study block'), findsOneWidget);
  });

  testWidgets('tool traces render as compact transcript tags', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _TestShell(
        child: ChatView(
          messages: <ChatMessage>[
            ChatMessage.toolTrace(
              toolName: 'get_study_context',
              status: 'done',
              summary: 'Attached profile, memory, device state.',
            ),
          ],
          inputController: controller,
          isSending: false,
          compactMessages: false,
          onSuggestionSelected: (_) {},
          onSend: () {},
        ),
      ),
    );

    expect(find.text('get_study_context'), findsOneWidget);
    expect(find.text('done'), findsOneWidget);
    expect(
      find.text('Attached profile, memory, device state.'),
      findsOneWidget,
    );
  });
}

class _TestShell extends StatelessWidget {
  const _TestShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildStudyOsTheme(),
      home: Scaffold(body: child),
    );
  }
}
