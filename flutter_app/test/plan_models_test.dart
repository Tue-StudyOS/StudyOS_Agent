import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/device_calendar_event.dart';
import 'package:studyos_agent/src/plan_models.dart';
import 'package:studyos_agent/src/talk_models.dart';
import 'package:studyos_agent/src/timetable_models.dart';

void main() {
  test('plan merges synced ALMA copies and keeps other calendar sources', () {
    final lecture = LectureEvent(
      id: 'ml-1',
      title: 'ML4510 Practical Machine Learning',
      start: DateTime(2026, 7, 16, 16),
      end: DateTime(2026, 7, 16, 18),
      location: 'A-206',
    );
    final syncedCopy = DeviceCalendarEvent(
      id: 'native-1',
      title: 'ML4510 Practical ML',
      start: DateTime(2026, 7, 16, 16, 15),
      end: DateTime(2026, 7, 16, 18, 15),
      isAllDay: false,
      calendarName: 'StudyOS',
      notes: 'StudyOS lecture id: ml-1\nStudyOS term: Summer 2026',
    );
    final personal = DeviceCalendarEvent(
      id: 'native-2',
      title: 'Dinner',
      start: DateTime(2026, 7, 16, 19),
      end: DateTime(2026, 7, 16, 20),
      isAllDay: false,
      calendarName: 'Personal',
    );
    const talk = Talk(
      id: 7,
      title: 'Reliable Agents',
      timestamp: '2026-07-16T14:00:00',
      description: null,
      location: 'AI Center',
      speakerName: 'Ada Lovelace',
      tags: <String>[],
    );

    final items = buildPlanItems(
      lectures: <LectureEvent>[lecture],
      talks: const <Talk>[talk],
      deviceEvents: <DeviceCalendarEvent>[syncedCopy, personal],
    );

    expect(items, hasLength(3));
    final course = items.singleWhere(
      (item) => item.source == PlanItemSource.alma,
    );
    expect(course.title, 'ML4510 Practical Machine Learning');
    expect(course.start, DateTime(2026, 7, 16, 16));
    expect(course.isSyncedToDevice, isTrue);
    expect(items.where((item) => item.id == 'device:native-1'), isEmpty);
    expect(
      items.singleWhere((item) => item.source == PlanItemSource.talk).end,
      isNull,
      reason: 'The Talks feed does not provide a duration.',
    );
    expect(planDays(items), <DateTime>[DateTime(2026, 7, 16)]);
    expect(planItemsOn(items, DateTime(2026, 7, 16)), hasLength(3));
  });

  test('unmatched StudyOS calendar events remain visible', () {
    final stale = DeviceCalendarEvent(
      id: 'stale',
      title: 'Old lecture copy',
      start: DateTime(2026, 7, 20, 10),
      end: DateTime(2026, 7, 20, 12),
      isAllDay: false,
      calendarName: 'StudyOS',
      notes: 'StudyOS lecture id: removed-lecture',
    );

    final items = buildPlanItems(
      lectures: const <LectureEvent>[],
      talks: const <Talk>[],
      deviceEvents: <DeviceCalendarEvent>[stale],
    );

    expect(items.single.source, PlanItemSource.deviceCalendar);
  });

  test('all synced copies are deduplicated without overriding ALMA', () {
    final lecture = LectureEvent(
      id: 'ml-1',
      title: 'Canonical ALMA title',
      start: DateTime(2026, 7, 20, 10),
      end: DateTime(2026, 7, 20, 12),
    );
    final copies = <DeviceCalendarEvent>[
      for (final id in <String>['copy-1', 'copy-2'])
        DeviceCalendarEvent(
          id: id,
          title: 'Edited device title',
          start: DateTime(2026, 7, 20, 11),
          end: DateTime(2026, 7, 20, 13),
          isAllDay: false,
          calendarName: 'StudyOS',
          notes: 'StudyOS lecture id: ml-1',
        ),
    ];

    final items = buildPlanItems(
      lectures: <LectureEvent>[lecture],
      talks: const <Talk>[],
      deviceEvents: copies,
    );

    expect(items, hasLength(1));
    expect(items.single.title, 'Canonical ALMA title');
    expect(items.single.start, DateTime(2026, 7, 20, 10));
    expect(items.single.isSyncedToDevice, isTrue);
  });

  test('merged ALMA aliases match every previously synced device copy', () {
    final lecture = LectureEvent(
      id: 'exam-a',
      sourceIds: const <String>['exam-b', 'exam-c'],
      title: 'ML4202 Probabilistic Machine Learning',
      start: DateTime(2026, 7, 23, 10),
      end: DateTime(2026, 7, 23, 13),
      detail: 'Klausur',
    );
    final copies = <DeviceCalendarEvent>[
      for (final sourceId in lecture.allSourceIds)
        DeviceCalendarEvent(
          id: 'native-$sourceId',
          title: lecture.title,
          start: lecture.start,
          end: lecture.end,
          isAllDay: false,
          calendarName: 'StudyOS',
          notes: 'StudyOS lecture id: $sourceId',
        ),
    ];

    final items = buildPlanItems(
      lectures: <LectureEvent>[lecture],
      talks: const <Talk>[],
      deviceEvents: copies,
    );

    expect(items, hasLength(1));
    expect(items.single.isSyncedToDevice, isTrue);

    final restored = TimetableSnapshot.decode(
      TimetableSnapshot(
        refreshedAt: DateTime(2026, 7, 16),
        sourceTerm: 'Sommer 2026',
        events: <LectureEvent>[lecture],
      ).encode(),
    );
    expect(restored!.events.single.sourceIds, lecture.sourceIds);
  });

  test('overnight and multi-day events appear on every overlapping day', () {
    final overnight = DeviceCalendarEvent(
      id: 'overnight',
      title: 'Hackathon',
      start: DateTime(2026, 7, 20, 22),
      end: DateTime(2026, 7, 21, 2),
      isAllDay: false,
      calendarName: 'Personal',
    );
    final trip = DeviceCalendarEvent(
      id: 'trip',
      title: 'Trip',
      start: DateTime(2026, 7, 21),
      end: DateTime(2026, 7, 24),
      isAllDay: true,
      calendarName: 'Personal',
    );
    final items = buildPlanItems(
      lectures: const <LectureEvent>[],
      talks: const <Talk>[],
      deviceEvents: <DeviceCalendarEvent>[overnight, trip],
    );

    expect(planDays(items), <DateTime>[
      DateTime(2026, 7, 20),
      DateTime(2026, 7, 21),
      DateTime(2026, 7, 22),
      DateTime(2026, 7, 23),
    ]);
    expect(planItemsOn(items, DateTime(2026, 7, 21)), hasLength(2));
    expect(planItemsOn(items, DateTime(2026, 7, 23)).single.title, 'Trip');
    expect(planItemsOn(items, DateTime(2026, 7, 24)), isEmpty);
  });

  test('device calendar maps preserve source and StudyOS marker', () {
    final event = DeviceCalendarEvent.fromMap(<String, Object?>{
      'id': '42',
      'title': 'Study block',
      'start': '2026-07-18T08:00:00Z',
      'end': '2026-07-18T09:00:00Z',
      'calendarName': 'University',
      'notes': 'StudyOS lecture id: algo-1',
      'allDay': false,
    });

    expect(event, isNotNull);
    expect(event!.calendarName, 'University');
    expect(event.studyOsLectureId, 'algo-1');
  });

  test('legacy StudyOS calendar copies repair their UTF-8 text', () {
    final event = DeviceCalendarEvent.fromMap(<String, Object?>{
      'id': '42',
      'title': 'ML4202 Ãbung',
      'start': '2026-07-18T08:00:00Z',
      'end': '2026-07-18T09:00:00Z',
      'location': 'HÃ¶rsaal A2, WilhelmstraÃe 19',
      'calendarName': 'Calendar',
      'notes': 'StudyOS lecture id: ml-1',
      'allDay': false,
    });

    expect(event!.title, 'ML4202 Übung');
    expect(event.location, 'Hörsaal A2, Wilhelmstraße 19');
  });
}
