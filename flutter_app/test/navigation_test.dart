import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/studyos_theme.dart';
import 'package:studyos_agent/src/widgets/agent_home_scaffold.dart';

void main() {
  testWidgets('bottom navigation switches main app views', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final inputController = TextEditingController();
    final scrollController = ScrollController();
    AppView selectedView = AppView.home;
    addTearDown(inputController.dispose);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudyOsTheme(),
        home: StatefulBuilder(
          builder: (context, setState) {
            return AgentHomeScaffold(
              selectedView: selectedView,
              sessions: <ChatSession>[ChatSession.fresh()],
              activeSessionId: null,
              inputController: inputController,
              messageScrollController: scrollController,
              isSending: false,
              compactMessages: false,
              status: 'Ready',
              worldState: const <String, Object?>{},
              memoryText: '',
              agentConfig: const AgentConfig.defaults(),
              profile: null,
              onSelectView: (value) => setState(() => selectedView = value),
              onSelectSession: (_) {},
              onCreateSession: () {},
              onDeleteSession: (_) {},
              onSuggestionSelected: (_) {},
              onSend: () {},
              onLogout: null,
              onSaveAgentConfig: (_, _) async {},
              onSaveMemory: (_) async {},
              onCompactMessagesChanged: (_) {},
            );
          },
        ),
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Campus'), findsOneWidget);

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(selectedView, AppView.schedule);
    expect(find.text('No timetable synced yet'), findsOneWidget);

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    expect(selectedView, AppView.chat);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('New chat'), findsOneWidget);
  });
}
