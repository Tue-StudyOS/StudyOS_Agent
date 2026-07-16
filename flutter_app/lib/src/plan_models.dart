import 'device_calendar_event.dart';
import 'talk_models.dart';
import 'timetable_models.dart';

enum PlanItemSource { alma, talk, deviceCalendar }

class PlanItem {
  const PlanItem({
    required this.id,
    required this.title,
    required this.start,
    required this.source,
    required this.sourceName,
    this.end,
    this.location,
    this.detail,
    this.isAllDay = false,
    this.isSyncedToDevice = false,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime? end;
  final String? location;
  final String? detail;
  final PlanItemSource source;
  final String sourceName;
  final bool isAllDay;
  final bool isSyncedToDevice;

  String get dayKey => _dayKey(start);

  bool isOngoingAt(DateTime now) {
    final finish = end;
    return finish != null && !now.isBefore(start) && now.isBefore(finish);
  }

  factory PlanItem.fromLecture(
    LectureEvent lecture, {
    bool isSyncedToDevice = false,
  }) => PlanItem(
    id: 'alma:${lecture.id}',
    title: lecture.title,
    start: lecture.start,
    end: lecture.end,
    location: lecture.location,
    detail: lecture.detail,
    source: PlanItemSource.alma,
    sourceName: 'ALMA',
    isSyncedToDevice: isSyncedToDevice,
  );

  factory PlanItem.fromTalk(Talk talk, DateTime start) => PlanItem(
    id: 'talk:${talk.id}',
    title: talk.title,
    start: start,
    location: talk.location,
    detail: talk.speakerName,
    source: PlanItemSource.talk,
    sourceName: 'TUE Talk',
  );

  factory PlanItem.fromDeviceEvent(DeviceCalendarEvent event) => PlanItem(
    id: 'device:${event.id}',
    title: event.title,
    start: event.start,
    end: event.end,
    location: event.location,
    source: PlanItemSource.deviceCalendar,
    sourceName: event.calendarName,
    isAllDay: event.isAllDay,
  );
}

List<PlanItem> buildPlanItems({
  required Iterable<LectureEvent> lectures,
  required Iterable<Talk> talks,
  required Iterable<DeviceCalendarEvent> deviceEvents,
}) {
  final syncedByLectureId = <String, List<DeviceCalendarEvent>>{};
  for (final event in deviceEvents) {
    final lectureId = event.studyOsLectureId;
    if (lectureId != null) {
      syncedByLectureId
          .putIfAbsent(lectureId, () => <DeviceCalendarEvent>[])
          .add(event);
    }
  }

  final matchedDeviceIds = <String>{};
  final items = <PlanItem>[];
  // ALMA stays canonical; marker-matched device copies only prove export.
  for (final lecture in lectures) {
    final syncedEventsById = <String, DeviceCalendarEvent>{};
    for (final sourceId in lecture.allSourceIds) {
      for (final event in syncedByLectureId[sourceId] ?? const []) {
        syncedEventsById[event.id] = event;
      }
    }
    final syncedEvents = syncedEventsById.values;
    matchedDeviceIds.addAll(syncedEvents.map((event) => event.id));
    items.add(
      PlanItem.fromLecture(lecture, isSyncedToDevice: syncedEvents.isNotEmpty),
    );
  }
  for (final talk in talks) {
    final start = talk.start;
    if (start != null) items.add(PlanItem.fromTalk(talk, start));
  }
  for (final event in deviceEvents) {
    if (!matchedDeviceIds.contains(event.id)) {
      items.add(PlanItem.fromDeviceEvent(event));
    }
  }

  items.sort((first, second) {
    final byStart = first.start.compareTo(second.start);
    if (byStart != 0) return byStart;
    return first.source.index.compareTo(second.source.index);
  });
  return items;
}

List<DateTime> planDays(Iterable<PlanItem> items) {
  final days = <String, DateTime>{};
  for (final item in items) {
    for (final day in _itemDays(item)) {
      days.putIfAbsent(_dayKey(day), () => day);
    }
  }
  final result = days.values.toList()..sort();
  return result;
}

List<PlanItem> planItemsOn(Iterable<PlanItem> items, DateTime day) {
  final startOfDay = DateTime(day.year, day.month, day.day);
  final startOfNextDay = DateTime(day.year, day.month, day.day + 1);
  return items.where((item) {
    final end = item.end;
    if (end == null || !end.isAfter(item.start)) {
      return item.dayKey == _dayKey(startOfDay);
    }
    return item.start.isBefore(startOfNextDay) && end.isAfter(startOfDay);
  }).toList()..sort((first, second) => first.start.compareTo(second.start));
}

Iterable<DateTime> _itemDays(PlanItem item) sync* {
  var day = DateTime(item.start.year, item.start.month, item.start.day);
  final end = item.end;
  final lastInstant = end != null && end.isAfter(item.start)
      ? end.subtract(const Duration(microseconds: 1))
      : item.start;
  final lastDay = DateTime(
    lastInstant.year,
    lastInstant.month,
    lastInstant.day,
  );
  while (!day.isAfter(lastDay)) {
    yield day;
    day = DateTime(day.year, day.month, day.day + 1);
  }
}

String _dayKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
