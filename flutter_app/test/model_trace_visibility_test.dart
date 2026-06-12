import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/message_trace_compaction.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/studyos_theme.dart';
import 'package:studyos_agent/src/views/chat_view.dart';

void main() {
  test('model request traces are hidden from conversation rows', () {
    final messages = compactTraceMessages(<ChatMessage>[
      ChatMessage.toolTrace(
        toolName: 'model:apple_foundation',
        status: 'done',
        summary: 'Using Apple Foundation Models.',
      ),
      ChatMessage.toolTrace(
        toolName: 'read_memories',
        status: 'done',
        summary: 'Read memory.',
      ),
    ]);

    expect(messages, hasLength(1));
    expect(messages.single.trace?.toolName, 'read_memories');
  });

  testWidgets('model traces do not render in chat', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    final scrollController = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      _TestShell(
        child: ChatView(
          messages: <ChatMessage>[
            ChatMessage.toolTrace(
              toolName: 'model:apple_foundation',
              status: 'done',
              summary: 'Using Apple Foundation Models.',
            ),
            ChatMessage.toolTrace(
              toolName: 'read_memories',
              status: 'done',
              summary: 'Read memory.',
            ),
          ],
          inputController: controller,
          messageScrollController: scrollController,
          isSending: false,
          compactMessages: false,
          onSuggestionSelected: (_) {},
          onSend: () {},
        ),
      ),
    );

    expect(find.text('model:apple_foundation'), findsNothing);
    expect(find.text('read_memories'), findsOneWidget);
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
