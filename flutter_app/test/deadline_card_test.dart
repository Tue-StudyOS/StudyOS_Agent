import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:studyos_agent/src/app_shell_controller.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/native_tool_router.dart';
import 'package:studyos_agent/src/widgets/deadline_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GeneratedUiComponent deadlineComponent() {
    final payload = generativeUiFixturePayloads.firstWhere(
      (payload) => payload['type'] == 'deadline_list',
    );
    return GenerativeUiRegistry.validate(payload).component!;
  }

  group('reminderTimeForDeadline', () {
    test('defaults to one day before the deadline', () {
      final due = DateTime(2026, 12, 11, 18);
      final when = reminderTimeForDeadline(
        due,
        now: DateTime(2026, 12, 1, 9),
      );
      expect(when, DateTime(2026, 12, 10, 18));
    });

    test('steps to one hour before when a day out is already past', () {
      final due = DateTime(2026, 12, 11, 18);
      final when = reminderTimeForDeadline(
        due,
        now: DateTime(2026, 12, 11, 10),
      );
      expect(when, DateTime(2026, 12, 11, 17));
    });

    test('never returns a time in the past for imminent deadlines', () {
      final now = DateTime(2026, 12, 11, 17, 45);
      final due = DateTime(2026, 12, 11, 18);
      final when = reminderTimeForDeadline(due, now: now);
      expect(when.isAfter(now), isTrue);
    });
  });

  group('DeadlineCard', () {
    testWidgets('renders a row per deadline with course and due date', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DeadlineCard(component: deadlineComponent())),
        ),
      );

      expect(find.text('2 upcoming deadlines'), findsOneWidget);
      expect(find.text('ML exercise sheet 7'), findsOneWidget);
      expect(find.text('Machine Learning'), findsOneWidget);
      expect(find.textContaining('Due '), findsWidgets);
    });

    testWidgets('Add reminder emits a ReminderComponentAction with the due date', (
      tester,
    ) async {
      final actions = <GeneratedComponentAction>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeadlineCard(
              component: deadlineComponent(),
              onAction: actions.add,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add reminder').first);
      await tester.pump();

      expect(actions, hasLength(1));
      final action = actions.single as ReminderComponentAction;
      expect(action.title, 'ML exercise sheet 7');
      expect(
        action.dueAt.isAtSameMomentAs(
          DateTime.parse('2026-12-11T18:00:00.000Z'),
        ),
        isTrue,
      );
    });
  });

  group('AppShellController reminder dispatch', () {
    test('routes a reminder action to the native create_reminder tool', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = null);

      final runner = _RecordingNativeToolRunner('Reminder set for Thursday.');
      final controller = AppShellController(
        initialProfile: null,
        initialOnLogout: null,
        initialOnSaveProfile: null,
        nativeToolRunner: runner,
      );
      addTearDown(controller.dispose);
      controller.createSession();

      controller.handleComponentAction(
        ReminderComponentAction(
          title: 'ML exercise sheet 7',
          dueAt: DateTime(2026, 12, 11, 18),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(runner.calls, hasLength(1));
      expect(runner.calls.single.name, nativeCreateReminderToolName);
      final args =
          jsonDecode(runner.calls.single.arguments) as Map<String, Object?>;
      expect(args['title'], 'ML exercise sheet 7');
      expect(args['time'], isNotNull);

      // The native tool's result is surfaced back to the user.
      final messages = controller.activeSession.messages;
      expect(messages.last.text, 'Reminder set for Thursday.');
    });
  });
}

class _RecordingNativeToolRunner implements NativeToolRunner {
  _RecordingNativeToolRunner(this._result);

  final String _result;
  final List<({String name, String arguments})> calls =
      <({String name, String arguments})>[];

  @override
  Future<Set<String>> supportedToolNames() async =>
      <String>{nativeCreateReminderToolName};

  @override
  Future<String> execute(String toolName, String arguments) async {
    calls.add((name: toolName, arguments: arguments));
    return _result;
  }
}
