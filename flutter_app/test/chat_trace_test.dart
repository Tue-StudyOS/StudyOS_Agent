import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/studyos_theme.dart';
import 'package:studyos_agent/src/views/chat_view.dart';
import 'package:studyos_agent/src/widgets/study_header.dart';

void main() {
  test('tool traces survive chat session persistence', () {
    final session = ChatSession.fresh().copyWith(
      messages: <ChatMessage>[
        ChatMessage.toolTrace(
          toolName: 'get_study_context',
          status: 'attached',
          summary: 'Attached profile.',
        ),
      ],
    );

    final decoded = ChatSession.decodeList(
      ChatSession.encodeList(<ChatSession>[session]),
    );

    expect(decoded.single.messages.single.trace?.toolName, 'get_study_context');
    expect(decoded.single.messages.single.trace?.status, 'attached');
  });

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

  testWidgets('tool traces render with visual status styling', (
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
    expect(find.text('done'), findsNothing);
    expect(
      find.text('Attached profile, memory, device state.'),
      findsOneWidget,
    );
    expect(find.byTooltip('done'), findsOneWidget);
  });

  testWidgets('conversation header stays minimal', (WidgetTester tester) async {
    await tester.pumpWidget(
      _TestShell(child: const StudyHeader(status: 'Ready')),
    );

    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('StudyOS Agent'), findsNothing);
    expect(find.text('Study companion'), findsNothing);
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
