import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:studyos_agent/src/app_router.dart';
import 'package:studyos_agent/src/app_shell_controller.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/studyos_theme.dart';
import 'package:studyos_agent/src/views/home_view.dart';
import 'package:studyos_agent/src/widgets/study_bottom_bar.dart';

void main() {
  testWidgets('bottom navigation exposes four tabs and centered ask action', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var selectedIndex = 0;
    var askPressed = false;
    var askLongPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudyOsTheme(),
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              floatingActionButton: AskFab(
                onPressed: () => askPressed = true,
                onLongPress: () => askLongPressed = true,
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerDocked,
              bottomNavigationBar: StudyBottomBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: (value) =>
                    setState(() => selectedIndex = value),
              ),
            );
          },
        ),
      ),
    );

    expect(find.byType(BottomAppBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Mail'), findsOneWidget);
    expect(find.text('Campus'), findsOneWidget);
    expect(find.text('Ask'), findsOneWidget);
    expect(find.text('Map'), findsNothing);
    expect(find.text('Notes'), findsNothing);

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(selectedIndex, 1);

    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();

    expect(askPressed, isTrue);

    await tester.longPress(
      find.byKey(const ValueKey<String>('ask-fab-surface')),
    );
    await tester.pumpAndSettle();

    expect(askLongPressed, isTrue);
  });

  testWidgets('home campus card opens campus view', (
    WidgetTester tester,
  ) async {
    var selectedTarget = 'home';

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
            snapshot: _testSnapshot(),
            memoryText: '',
            timetable: null,
            onOpenProfile: () => selectedTarget = 'profile',
            onOpenAssistant: () => selectedTarget = 'assistant',
            onOpenNotes: () => selectedTarget = 'notes',
            onOpenMail: () => selectedTarget = 'mail',
            onOpenMaps: () => selectedTarget = 'maps',
            onOpenCampus: () => selectedTarget = 'campus',
            onOpenSchedule: () => selectedTarget = 'schedule',
            onRefresh: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Hi Ada'), findsOneWidget);
    expect(find.text('M.Sc. AI · Semester 2'), findsOneWidget);

    final campusCard = find.byKey(const ValueKey<String>('home-campus-card'));
    await tester.scrollUntilVisible(
      campusCard,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(campusCard);

    expect(selectedTarget, 'campus');
  });

  testWidgets('home inbox card opens mail view', (WidgetTester tester) async {
    var selectedTarget = 'home';

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudyOsTheme(),
        home: Scaffold(
          body: HomeView(
            profile: null,
            config: const AgentConfig.defaults(),
            snapshot: _testSnapshot(),
            memoryText: '',
            timetable: null,
            onOpenProfile: () => selectedTarget = 'profile',
            onOpenAssistant: () => selectedTarget = 'assistant',
            onOpenNotes: () => selectedTarget = 'notes',
            onOpenMail: () => selectedTarget = 'mail',
            onOpenMaps: () => selectedTarget = 'maps',
            onOpenCampus: () => selectedTarget = 'campus',
            onOpenSchedule: () => selectedTarget = 'schedule',
            onRefresh: () async {},
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Inbox'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Inbox'));

    expect(selectedTarget, 'mail');
  });

  testWidgets('home navigation card opens maps view', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var selectedTarget = 'home';

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudyOsTheme(),
        home: Scaffold(
          body: HomeView(
            profile: null,
            config: const AgentConfig.defaults(),
            snapshot: _testSnapshot(),
            memoryText: '',
            timetable: null,
            onOpenProfile: () => selectedTarget = 'profile',
            onOpenAssistant: () => selectedTarget = 'assistant',
            onOpenNotes: () => selectedTarget = 'notes',
            onOpenMail: () => selectedTarget = 'mail',
            onOpenMaps: () => selectedTarget = 'maps',
            onOpenCampus: () => selectedTarget = 'campus',
            onOpenSchedule: () => selectedTarget = 'schedule',
            onRefresh: () async {},
          ),
        ),
      ),
    );

    final mapsCard = find.byKey(const ValueKey<String>('home-maps-card'));
    await _bringCardIntoTapArea(tester, mapsCard);
    await tester.tap(mapsCard);

    expect(selectedTarget, 'maps');
  });

  testWidgets('home status grid items open their destinations', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var selectedTarget = 'home';

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
            ),
            config: const AgentConfig.defaults(),
            snapshot: _testSnapshot(),
            memoryText: 'Prefers morning study blocks.',
            timetable: null,
            onOpenProfile: () => selectedTarget = 'profile',
            onOpenAssistant: () => selectedTarget = 'assistant',
            onOpenNotes: () => selectedTarget = 'notes',
            onOpenMail: () => selectedTarget = 'mail',
            onOpenMaps: () => selectedTarget = 'maps',
            onOpenCampus: () => selectedTarget = 'campus',
            onOpenSchedule: () => selectedTarget = 'schedule',
            onRefresh: () async {},
          ),
        ),
      ),
    );

    Future<void> tapStatus(String key, String expectedTarget) async {
      final finder = find.byKey(ValueKey<String>(key));
      await _bringCardIntoTapArea(tester, finder);
      await tester.tap(finder);
      await tester.pump();
      expect(selectedTarget, expectedTarget);
    }

    await tapStatus('home-status-profile', 'profile');
    await tapStatus('home-status-assistant', 'assistant');
    await tapStatus('home-status-notes', 'notes');
    await tapStatus('home-status-timetable', 'schedule');
    await tapStatus('home-status-mail', 'mail');
    await tapStatus('home-status-map', 'maps');
  });

  testWidgets('home renders proactive snapshot before cards', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudyOsTheme(),
        home: Scaffold(
          body: HomeView(
            profile: null,
            config: const AgentConfig.defaults(),
            snapshot: HomeFeedSnapshot.fromLocalState(
              profile: null,
              timetable: null,
              memoryText: '',
              now: DateTime(2026, 7, 1, 9),
            ),
            memoryText: '',
            timetable: null,
            onOpenProfile: () {},
            onOpenAssistant: () {},
            onOpenNotes: () {},
            onOpenMail: () {},
            onOpenMaps: () {},
            onOpenCampus: () {},
            onOpenSchedule: () {},
            onRefresh: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Set up your StudyOS'), findsOneWidget);
    expect(find.textContaining('Connect your profile'), findsOneWidget);
    expect(find.text('Timetable: Unavailable'), findsOneWidget);
    expect(find.text('Generated component preview'), findsOneWidget);
    expect(find.text('Leave for class'), findsOneWidget);

    await tester.tap(find.byTooltip('Next component'));
    await tester.pump();

    expect(find.text('Compact day'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  test(
    'home feed snapshot summarizes the next lecture from structured state',
    () {
      final now = DateTime(2026, 7, 1, 9);
      final snapshot = HomeFeedSnapshot.fromLocalState(
        profile: const OnboardingProfile(
          displayName: 'Ada',
          username: 'ada42',
          email: null,
          degreeProgram: 'M.Sc. AI',
          semester: 2,
          livesInTuebingen: true,
        ),
        timetable: TimetableSnapshot(
          refreshedAt: now,
          sourceTerm: 'Sommer 2026',
          events: <LectureEvent>[
            LectureEvent(
              id: 'algorithms',
              title: 'Algorithms',
              start: now.add(const Duration(minutes: 45)),
              end: now.add(const Duration(hours: 2)),
              location: 'Room 101',
            ),
          ],
        ),
        memoryText: '',
        now: now,
      );

      expect(snapshot.summary.title, 'Today at a glance');
      expect(snapshot.summary.body, contains('Algorithms'));
      expect(snapshot.summary.body, contains('in 45 min'));
      expect(snapshot.nextAction.title, 'Prepare for next lecture');
    },
  );

  testWidgets('shell swipes between primary tabs and updates location', (
    WidgetTester tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = null);

    const profile = OnboardingProfile(
      displayName: 'Ada',
      username: 'ada42',
      email: null,
      degreeProgram: 'M.Sc. AI',
      semester: 2,
      livesInTuebingen: true,
    );
    final authState = AuthRouterState(
      initialSession: const UserSession(username: 'ada42'),
      initialProfile: profile,
      initialLoading: false,
    );
    final controller = AppShellController(
      initialProfile: profile,
      initialOnLogout: () {},
      initialOnSaveProfile: (_) async {},
    );
    final router = buildAppRouter(
      authState: authState,
      shellController: () => controller,
      onLogin: (_, _) async {},
      onOnboardingComplete: (_) async {},
    );
    addTearDown(router.dispose);
    addTearDown(controller.dispose);
    addTearDown(authState.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: buildStudyOsTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/home');

    await tester.fling(
      find.byKey(const ValueKey<String>('shell-swipe-area')),
      const Offset(-500, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/schedule');

    await tester.fling(
      find.byKey(const ValueKey<String>('shell-swipe-area')),
      const Offset(500, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/home');
  });

  testWidgets('ask button long press opens voice input spike', (
    WidgetTester tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = null);

    const profile = OnboardingProfile(
      displayName: 'Ada',
      username: 'ada42',
      email: null,
      degreeProgram: 'M.Sc. AI',
      semester: 2,
      livesInTuebingen: true,
    );
    final authState = AuthRouterState(
      initialSession: const UserSession(username: 'ada42'),
      initialProfile: profile,
      initialLoading: false,
    );
    final controller = AppShellController(
      initialProfile: profile,
      initialOnLogout: () {},
      initialOnSaveProfile: (_) async {},
    );
    final router = buildAppRouter(
      authState: authState,
      shellController: () => controller,
      onLogin: (_, _) async {},
      onOnboardingComplete: (_) async {},
    );
    addTearDown(router.dispose);
    addTearDown(controller.dispose);
    addTearDown(authState.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: buildStudyOsTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey<String>('ask-fab-surface')),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/voice');
    expect(find.text('Voice input spike'), findsOneWidget);
    expect(find.text('Push-to-talk'), findsOneWidget);
    expect(find.text('Custom hotword'), findsOneWidget);
    expect(find.text('Passive listener'), findsOneWidget);
  });

  testWidgets('chat route prompt is applied after route build', (
    WidgetTester tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    const profile = OnboardingProfile(
      displayName: 'Ada',
      username: 'ada42',
      email: null,
      degreeProgram: 'M.Sc. AI',
      semester: 2,
      livesInTuebingen: true,
    );
    final authState = AuthRouterState(
      initialSession: const UserSession(username: 'ada42'),
      initialProfile: profile,
      initialLoading: false,
    );
    final controller = AppShellController(
      initialProfile: profile,
      initialOnLogout: () {},
      initialOnSaveProfile: (_) async {},
    );
    final router = buildAppRouter(
      authState: authState,
      shellController: () => controller,
      onLogin: (_, _) async {},
      onOnboardingComplete: (_) async {},
    );
    addTearDown(router.dispose);
    addTearDown(controller.dispose);
    addTearDown(authState.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: buildStudyOsTheme(), routerConfig: router),
    );

    router.go('/chat?prompt=Campus%20Library');
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(controller.inputController.text, 'Campus Library');
  });
}

HomeFeedSnapshot _testSnapshot() {
  return HomeFeedSnapshot.fromLocalState(
    profile: null,
    timetable: null,
    memoryText: '',
    now: DateTime(2026, 7, 1, 9),
  );
}

Future<void> _bringCardIntoTapArea(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(finder, 300, scrollable: scrollable);
  final viewportHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final centerY = tester.getCenter(finder).dy;
  const safeInset = 72.0;
  if (centerY > viewportHeight - safeInset) {
    await tester.drag(
      scrollable,
      Offset(0, -(centerY - viewportHeight + safeInset)),
    );
    await tester.pumpAndSettle();
  } else if (centerY < safeInset) {
    await tester.drag(scrollable, Offset(0, safeInset - centerY));
    await tester.pumpAndSettle();
  }
}
