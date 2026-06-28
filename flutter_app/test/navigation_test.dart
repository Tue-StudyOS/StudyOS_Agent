import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
