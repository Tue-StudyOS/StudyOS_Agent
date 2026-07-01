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

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudyOsTheme(),
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              floatingActionButton: AskFab(
                onPressed: () => askPressed = true,
                onLongPress: () {},
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
            memoryText: '',
            timetable: null,
            onOpenMail: () => selectedTarget = 'mail',
            onOpenMaps: () => selectedTarget = 'maps',
            onOpenCampus: () => selectedTarget = 'campus',
            onOpenSchedule: () => selectedTarget = 'schedule',
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
            memoryText: '',
            timetable: null,
            onOpenMail: () => selectedTarget = 'mail',
            onOpenMaps: () => selectedTarget = 'maps',
            onOpenCampus: () => selectedTarget = 'campus',
            onOpenSchedule: () => selectedTarget = 'schedule',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Inbox'));

    expect(selectedTarget, 'mail');
  });

  testWidgets('home navigation card opens maps view', (
    WidgetTester tester,
  ) async {
    var selectedTarget = 'home';

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudyOsTheme(),
        home: Scaffold(
          body: HomeView(
            profile: null,
            config: const AgentConfig.defaults(),
            memoryText: '',
            timetable: null,
            onOpenMail: () => selectedTarget = 'mail',
            onOpenMaps: () => selectedTarget = 'maps',
            onOpenCampus: () => selectedTarget = 'campus',
            onOpenSchedule: () => selectedTarget = 'schedule',
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

    expect(selectedTarget, 'maps');
  });

  testWidgets('chat route prompt is applied after route build', (
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

    router.go('/chat?prompt=Campus%20Library');
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(controller.inputController.text, 'Campus Library');
  });
}
