import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/studyos_theme.dart';
import 'package:studyos_agent/src/views/chat_view.dart';
import 'package:studyos_agent/src/widgets/app_drawer.dart';

void main() {
  testWidgets('chat view starts clean with suggestions and composer', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _TestShell(
        child: ChatView(
          messages: const <ChatMessage>[],
          inputController: controller,
          isSending: false,
          compactMessages: false,
          onSuggestionSelected: (value) => controller.text = value,
          onSend: () {},
        ),
      ),
    );

    expect(find.text('Summarize today'), findsOneWidget);
    expect(find.text('Find next lecture'), findsOneWidget);
    expect(find.text('Plan study block'), findsOneWidget);
    expect(find.text('Nachricht an Jarvis...'), findsOneWidget);
    expect(find.text('Native'), findsNothing);
    expect(find.textContaining('Ask about lectures'), findsNothing);
  });

  testWidgets('drawer exposes view icons and persisted chat sessions', (
    WidgetTester tester,
  ) async {
    final session = ChatSession.fresh().copyWith(title: 'Algorithms review');

    await tester.pumpWidget(
      _TestShell(
        child: AppDrawer(
          selectedView: AppView.chat,
          sessions: <ChatSession>[session],
          activeSessionId: session.id,
          onSelectView: (_) {},
          onSelectSession: (_) {},
          onCreateSession: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.psychology_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.text('New chat'), findsOneWidget);
    expect(find.text(session.title), findsOneWidget);
    expect(find.textContaining('Active ID:'), findsOneWidget);
    expect(find.text('Capabilities'), findsNothing);
    expect(find.text('World State'), findsNothing);
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
