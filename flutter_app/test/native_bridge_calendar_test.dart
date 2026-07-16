import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/native_bridge.dart';
import 'package:studyos_agent/src/timetable_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('studyos/native');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('native bridge decodes structured device calendar events', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          captured = call;
          return <Map<String, Object?>>[
            <String, Object?>{
              'id': 'native-1',
              'title': 'Project meeting',
              'start': '2026-07-18T08:00:00Z',
              'end': '2026-07-18T09:00:00Z',
              'calendarName': 'Work',
            },
          ];
        });

    final events = await NativeBridge().listDeviceCalendarEvents(
      start: DateTime.utc(2026, 7, 18),
      end: DateTime.utc(2026, 7, 19),
    );

    expect(captured?.method, 'listDeviceCalendarEvents');
    expect(captured?.arguments, containsPair('limit', 250));
    expect(events.single['title'], 'Project meeting');
    expect(events.single['calendarName'], 'Work');
  });

  test('calendar sync sends merged ALMA source identifiers', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          captured = call;
          return 'Synced';
        });
    final refreshedAt = DateTime(2026, 7, 16);
    final event = LectureEvent(
      id: 'exam-a',
      sourceIds: const <String>['exam-b', 'exam-c'],
      title: 'ML4202 Probabilistic Machine Learning',
      start: DateTime(2026, 7, 23, 10),
      end: DateTime(2026, 7, 23, 13),
      detail: 'Klausur',
    );

    await NativeBridge().syncScheduleToCalendar(
      TimetableSnapshot(
        refreshedAt: refreshedAt,
        sourceTerm: 'Sommer 2026',
        events: <LectureEvent>[event],
      ),
    );

    expect(captured?.method, 'syncScheduleToCalendar');
    final arguments = Map<String, Object?>.from(captured!.arguments as Map);
    expect(arguments['windowStart'], refreshedAt.toIso8601String());
    expect(
      arguments['windowEnd'],
      refreshedAt.add(timetableLookAhead).toIso8601String(),
    );
    final lectures = arguments['lectures']! as List<Object?>;
    final serialized = Map<String, Object?>.from(lectures.single! as Map);
    expect(serialized['sourceIds'], <String>['exam-b', 'exam-c']);
  });

  test(
    'calendar sync keeps an authoritative window with no lectures',
    () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            captured = call;
            return 'Synced';
          });

      final refreshedAt = DateTime(2026, 7, 16);
      await NativeBridge().syncScheduleToCalendar(
        TimetableSnapshot(
          refreshedAt: refreshedAt,
          sourceTerm: 'Sommer 2026',
          events: const <LectureEvent>[],
        ),
      );

      final arguments = Map<String, Object?>.from(captured!.arguments as Map);
      expect(arguments['windowStart'], refreshedAt.toIso8601String());
      expect(
        arguments['windowEnd'],
        refreshedAt.add(timetableLookAhead).toIso8601String(),
      );
      expect(arguments['lectures'], isEmpty);
    },
  );
}
