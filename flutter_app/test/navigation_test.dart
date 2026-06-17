import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/native_bridge.dart';
import 'package:studyos_agent/src/studyos_theme.dart';
import 'package:studyos_agent/src/views/home_view.dart';
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
              timetable: null,
              timetableError: null,
              isRefreshingTimetable: false,
              agentConfig: const AgentConfig.defaults(),
              nativeBridge: NativeBridge(),
              profile: null,
              onSelectView: (value) => setState(() => selectedView = value),
              onSelectSession: (_) {},
              onCreateSession: () {},
              onDeleteSession: (_) {},
              onSuggestionSelected: (_) {},
              onSend: () {},
              onAskAssistant: (_) {},
              onLogout: null,
              onSaveProfile: (_) async {},
              onSaveAgentConfig: (_, _) async {},
              onSaveMemory: (_) async {},
              onRefreshTimetable: () async {},
              onCompactMessagesChanged: (_) {},
            );
          },
        ),
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Mail'), findsWidgets);
    expect(find.text('Map'), findsWidgets);
    expect(find.text('Campus'), findsWidgets);

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(selectedView, AppView.schedule);
    expect(find.text('No timetable synced yet'), findsOneWidget);

    await tester.tap(find.text('Map'));
    await tester.pump();

    expect(selectedView, AppView.maps);
    expect(find.text('Maps'), findsOneWidget);

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    expect(selectedView, AppView.chat);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('New chat'), findsOneWidget);
  });

  testWidgets('home campus card opens campus view', (
    WidgetTester tester,
  ) async {
    var selectedView = AppView.home;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudyOsTheme(),
        home: Scaffold(
          body: HomeView(
            profile: const OnboardingProfile(
              displayName: 'Ada',
              username: 'ada42',
              email: null,
              degreeProgram: 'M.Sc. AI',
              semester: 2,
              livesInTuebingen: true,
              interests: <StudyInterest>{StudyInterest.mensa},
              foodPreference: FoodPreference.vegan,
            ),
            config: const AgentConfig.defaults(),
            memoryText: '',
            timetable: null,
            onOpenMail: () => selectedView = AppView.mail,
            onOpenMaps: () => selectedView = AppView.maps,
            onOpenCampus: () => selectedView = AppView.campus,
            onOpenSchedule: () => selectedView = AppView.schedule,
          ),
        ),
      ),
    );

    final campusCard = find.byKey(const ValueKey<String>('home-campus-card'));
    await tester.scrollUntilVisible(
      campusCard,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(campusCard);

    expect(selectedView, AppView.campus);
  });

  testWidgets('home inbox card opens mail view', (WidgetTester tester) async {
    var selectedView = AppView.home;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudyOsTheme(),
        home: Scaffold(
          body: HomeView(
            profile: null,
            config: const AgentConfig.defaults(),
            memoryText: '',
            timetable: null,
            onOpenMail: () => selectedView = AppView.mail,
            onOpenMaps: () => selectedView = AppView.maps,
            onOpenCampus: () => selectedView = AppView.campus,
            onOpenSchedule: () => selectedView = AppView.schedule,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Inbox'));

    expect(selectedView, AppView.mail);
  });

  testWidgets('home navigation card opens maps view', (
    WidgetTester tester,
  ) async {
    var selectedView = AppView.home;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudyOsTheme(),
        home: Scaffold(
          body: HomeView(
            profile: null,
            config: const AgentConfig.defaults(),
            memoryText: '',
            timetable: null,
            onOpenMail: () => selectedView = AppView.mail,
            onOpenMaps: () => selectedView = AppView.maps,
            onOpenCampus: () => selectedView = AppView.campus,
            onOpenSchedule: () => selectedView = AppView.schedule,
          ),
        ),
      ),
    );

    final mapsCard = find.byKey(const ValueKey<String>('home-maps-card'));
    await tester.scrollUntilVisible(
      mapsCard,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(mapsCard);

    expect(selectedView, AppView.maps);
  });
}
