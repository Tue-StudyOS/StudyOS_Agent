import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:studyos_agent/src/app_shell_controller.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/timetable_repository.dart';
import 'package:studyos_agent/src/widgets/schedule_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GeneratedUiComponent scheduleComponent() {
    final payload = generativeUiFixturePayloads.firstWhere(
      (payload) => payload['type'] == 'schedule_agenda',
    );
    return GenerativeUiRegistry.validate(payload).component!;
  }

  group('ScheduleCard', () {
    testWidgets('groups lectures by day with time and room', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ScheduleCard(component: scheduleComponent())),
        ),
      );

      expect(find.text('Schedule · WS 2026/27'), findsOneWidget);
      expect(find.text('Machine Learning'), findsOneWidget);
      expect(find.text('Hörsaal 21'), findsOneWidget);
      // Two distinct days (9th and 10th) → two upper-cased day headers.
      expect(find.textContaining('9 DEC'), findsOneWidget);
      expect(find.textContaining('10 DEC'), findsOneWidget);
      expect(find.text('10:15–11:45'), findsOneWidget);
    });
  });

  group('readScheduleForAgent', () {
    test('emits structured JSON of upcoming events', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = null);

      // The timetable refresh reads device world state after fetching; stub the
      // native channel so it returns an empty map instead of throwing.
      const channel = MethodChannel('studyos/native');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getWorldState') return <String, Object?>{};
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      const profile = OnboardingProfile(
        displayName: 'Ada',
        username: 'ada42',
        email: null,
        degreeProgram: 'M.Sc. AI',
        semester: 2,
        livesInTuebingen: true,
      );
      final future = DateTime.now().add(const Duration(days: 1));
      final repository = _FakeTimetableRepository(
        TimetableSnapshot(
          refreshedAt: DateTime.now(),
          sourceTerm: 'WS 2026/27',
          events: <LectureEvent>[
            LectureEvent(
              id: 'ml-1',
              title: 'Machine Learning',
              start: future,
              end: future.add(const Duration(minutes: 90)),
              location: 'Hörsaal 21',
            ),
          ],
        ),
      );
      final controller = AppShellController(
        initialProfile: profile,
        initialOnLogout: null,
        initialOnSaveProfile: null,
        timetableRepository: repository,
      );
      addTearDown(controller.dispose);

      final result = await controller.readScheduleForAgent();
      final decoded = jsonDecode(result) as Map<String, Object?>;

      expect(decoded['source_term'], 'WS 2026/27');
      final events = decoded['events'] as List<Object?>;
      expect(events, hasLength(1));
      expect(
        (events.first as Map<Object?, Object?>)['title'],
        'Machine Learning',
      );
      // Refresh was requested exactly once (no null-snapshot race).
      expect(repository.refreshCalls, 1);
    });
  });
}

class _FakeTimetableRepository extends TimetableRepository {
  _FakeTimetableRepository(this._snapshot);

  final TimetableSnapshot _snapshot;
  int refreshCalls = 0;

  @override
  Future<TimetableSnapshot?> load() async => null;

  @override
  Future<TimetableSnapshot> refresh(OnboardingProfile profile) async {
    refreshCalls++;
    return _snapshot;
  }
}
