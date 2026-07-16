import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:studyos_agent/src/app_router.dart';
import 'package:studyos_agent/src/app_shell_controller.dart';
import 'package:studyos_agent/src/calendar_overview_repository.dart';
import 'package:studyos_agent/src/device_calendar_event.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/studyos_theme.dart';
import 'package:studyos_agent/src/talk_models.dart';
import 'package:studyos_agent/src/views/home_view.dart';
import 'package:studyos_agent/src/views/schedule_view.dart';
import 'package:studyos_agent/src/widgets/study_bottom_bar.dart';

void main() {
  testWidgets('bottom navigation exposes stable tabs and an assistant entry', (
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
              bottomNavigationBar: StudyBottomBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: (value) =>
                    setState(() => selectedIndex = value),
                onAssistantPressed: () => askPressed = true,
                onAssistantLongPress: () => askLongPressed = true,
              ),
            );
          },
        ),
      ),
    );

    expect(find.byType(BottomAppBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Assistant'), findsOneWidget);
    expect(find.text('Map'), findsNothing);
    expect(find.text('Notes'), findsNothing);

    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();

    expect(selectedIndex, 1);

    await tester.tap(find.byKey(const ValueKey<String>('assistant-tab')));
    await tester.pumpAndSettle();

    expect(askPressed, isTrue);

    await tester.longPress(find.byKey(const ValueKey<String>('assistant-tab')));
    await tester.pumpAndSettle();

    expect(askLongPressed, isTrue);
  });

  testWidgets('schedule view sync button calls calendar sync', (
    WidgetTester tester,
  ) async {
    var synced = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudyOsTheme(),
        home: Scaffold(
          body: ScheduleView(
            snapshot: _testTimetable(),
            error: null,
            isRefreshing: false,
            onRefresh: () async {},
            calendarOverviewSource: const _EmptyCalendarOverviewSource(),
            onSyncCalendar: () async => synced = true,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('schedule-sync-calendar')),
    );
    await tester.pumpAndSettle();

    expect(synced, isTrue);
  });

  testWidgets('schedule combines classes, talks, and personal calendar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final day = DateTime.now().add(const Duration(days: 1));
    final start = DateTime(day.year, day.month, day.day, 10);
    final overview = CalendarOverviewSnapshot(
      talks: <Talk>[
        Talk(
          id: 1,
          title: 'Reliable Agents',
          timestamp: start.add(const Duration(hours: 2)).toIso8601String(),
          description: null,
          location: 'AI Center',
          speakerName: 'Ada Lovelace',
          tags: const <String>[],
        ),
      ],
      deviceEvents: <DeviceCalendarEvent>[
        DeviceCalendarEvent(
          id: 'personal-1',
          title: 'Project meeting',
          start: start.add(const Duration(hours: 4)),
          end: start.add(const Duration(hours: 5)),
          isAllDay: false,
          calendarName: 'Personal',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudyOsTheme(),
        home: Scaffold(
          body: ScheduleView(
            snapshot: TimetableSnapshot(
              refreshedAt: DateTime.now(),
              sourceTerm: 'Summer 2026',
              events: <LectureEvent>[
                LectureEvent(
                  id: 'class-1',
                  title: 'ML4510 Practical Machine Learning',
                  start: start,
                  end: start.add(const Duration(hours: 1)),
                ),
              ],
            ),
            error: null,
            isRefreshing: false,
            onRefresh: () async {},
            calendarOverviewSource: _FixedCalendarOverviewSource(overview),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 Class'), findsOneWidget);
    expect(find.text('1 Talk'), findsOneWidget);
    expect(find.text('1 Other event'), findsOneWidget);
    expect(find.text('3 calendar items'), findsOneWidget);
    expect(find.text('Reliable Agents'), findsOneWidget);
    expect(find.text('Project meeting'), findsOneWidget);
    expect(find.textContaining('sessions'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home presents a daily focus before StudyOS controls', (
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
            onOpenTalks: () {},
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
    expect(find.text('For you'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('StudyOS'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('StudyOS'), findsOneWidget);
    expect(find.text('Tübingen Talks'), findsOneWidget);
    expect(find.text('Generated component preview'), findsNothing);
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
      calendarOverviewSource: const _EmptyCalendarOverviewSource(),
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

    expect(router.routeInformationProvider.value.uri.path, '/plan');

    await tester.fling(
      find.byKey(const ValueKey<String>('shell-swipe-area')),
      const Offset(500, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/home');
  });

  testWidgets('assistant tab long press opens voice input spike', (
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

    await tester.longPress(find.byKey(const ValueKey<String>('assistant-tab')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/voice');
    expect(find.text('Voice'), findsOneWidget);
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

TimetableSnapshot _testTimetable() {
  return TimetableSnapshot(
    refreshedAt: DateTime(2026, 7, 1, 9),
    sourceTerm: 'Summer 2026',
    events: <LectureEvent>[
      LectureEvent(
        id: 'algorithms-1',
        title: 'Algorithms',
        start: DateTime(2026, 7, 2, 10),
        end: DateTime(2026, 7, 2, 12),
        location: 'Room 101',
      ),
    ],
  );
}

class _EmptyCalendarOverviewSource implements CalendarOverviewSource {
  const _EmptyCalendarOverviewSource();

  @override
  Future<CalendarOverviewSnapshot> load({
    required DateTime start,
    required DateTime end,
    bool refreshTalks = false,
  }) async => CalendarOverviewSnapshot.empty;
}

class _FixedCalendarOverviewSource implements CalendarOverviewSource {
  const _FixedCalendarOverviewSource(this.snapshot);

  final CalendarOverviewSnapshot snapshot;

  @override
  Future<CalendarOverviewSnapshot> load({
    required DateTime start,
    required DateTime end,
    bool refreshTalks = false,
  }) async => snapshot;
}
