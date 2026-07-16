import 'lecture_occurrence_merge.dart';
import 'timetable_models.dart';

part 'ics_parser_values.dart';

class IcsParser {
  const IcsParser();

  List<LectureEvent> parseUpcoming(String rawIcs, {DateTime? now}) {
    final windowStart = now ?? DateTime.now();
    final windowEnd = windowStart.add(timetableLookAhead);
    final events = _events(rawIcs);
    // A detached VEVENT replaces its series occurrence at RECURRENCE-ID.
    final overrides = <String, _IcsEvent>{};
    final orphanedOverrides = <_IcsEvent>[];
    for (final event in events.where(
      (candidate) => candidate.recurrenceId != null,
    )) {
      final uid = event.uid;
      if (uid == null || uid.isEmpty) {
        orphanedOverrides.add(event);
        continue;
      }
      final key = _overrideKey(uid, event.recurrenceId!);
      final previous = overrides[key];
      if (previous == null || event.sequence >= previous.sequence) {
        overrides[key] = event;
      }
    }
    final overriddenStarts = <String, Set<int>>{};
    for (final override in overrides.values) {
      overriddenStarts
          .putIfAbsent(override.uid!, () => <int>{})
          .add(override.recurrenceId!.microsecondsSinceEpoch);
    }
    final expanded = <LectureEvent>[];
    for (final event in events.where(
      (candidate) => candidate.recurrenceId == null,
    )) {
      if (event.isCancelled) continue;
      expanded.addAll(
        _expand(
          event,
          windowStart,
          windowEnd,
          overriddenStarts: overriddenStarts[event.uid] ?? const <int>{},
        ),
      );
    }
    for (final event in <_IcsEvent>[
      ...overrides.values,
      ...orphanedOverrides,
    ]) {
      if (event.isCancelled ||
          !_overlaps(event.start, event.end, windowStart, windowEnd)) {
        continue;
      }
      expanded.add(_lecture(event, event.recurrenceId ?? event.start));
    }
    return mergeLectureOccurrences(expanded);
  }

  List<_IcsEvent> _events(String rawIcs) {
    final lines = _unfold(rawIcs);
    final events = <_IcsEvent>[];
    Map<String, List<_IcsProperty>>? current;
    for (final line in lines) {
      final property = _parseLine(line);
      if (property == null) continue;
      if (property.name == 'BEGIN' && property.value == 'VEVENT') {
        current = <String, List<_IcsProperty>>{};
        continue;
      }
      if (property.name == 'END' && property.value == 'VEVENT') {
        final event = current == null ? null : _eventFrom(current);
        if (event != null) events.add(event);
        current = null;
        continue;
      }
      current?[property.name] = <_IcsProperty>[
        ...current[property.name] ?? const <_IcsProperty>[],
        property,
      ];
    }
    return events;
  }

  _IcsEvent? _eventFrom(Map<String, List<_IcsProperty>> fields) {
    final recurrence = fields['RECURRENCE-ID']?.firstOrNull;
    final recurrenceDate = recurrence == null ? null : _parseDate(recurrence);
    final start = fields['DTSTART']?.firstOrNull;
    final startDate = start == null ? recurrenceDate : _parseDate(start);
    if (startDate == null) return null;
    final end = fields['DTEND']?.firstOrNull;
    return _IcsEvent(
      uid: _text(fields['UID']?.firstOrNull),
      title: _text(fields['SUMMARY']?.firstOrNull) ?? 'Untitled lecture',
      start: startDate,
      end: end == null ? null : _parseDate(end),
      location: _text(fields['LOCATION']?.firstOrNull),
      detail: _text(fields['DESCRIPTION']?.firstOrNull),
      recurrenceId: recurrenceDate,
      sequence:
          int.tryParse(fields['SEQUENCE']?.firstOrNull?.value.trim() ?? '') ??
          0,
      isCancelled:
          fields['STATUS']?.firstOrNull?.value.trim().toUpperCase() ==
          'CANCELLED',
      rule: fields['RRULE']?.firstOrNull?.value,
      excludedStarts: (fields['EXDATE'] ?? const <_IcsProperty>[])
          .expand(
            (property) => property.value
                .split(',')
                .map((value) => property.copyWith(value: value)),
          )
          .map(_parseDate)
          .whereType<DateTime>()
          .map((date) => date.microsecondsSinceEpoch)
          .toSet(),
    );
  }

  List<LectureEvent> _expand(
    _IcsEvent event,
    DateTime windowStart,
    DateTime windowEnd, {
    Set<int> overriddenStarts = const <int>{},
  }) {
    final rule = event.rule;
    if (rule == null || rule.isEmpty) {
      return !overriddenStarts.contains(event.start.microsecondsSinceEpoch) &&
              _overlaps(event.start, event.end, windowStart, windowEnd)
          ? <LectureEvent>[_lecture(event, event.start)]
          : const <LectureEvent>[];
    }
    final parts = Map<String, String>.fromEntries(
      rule.split(';').where((part) => part.contains('=')).map((part) {
        final pieces = part.split('=');
        return MapEntry(
          pieces.first.toUpperCase(),
          pieces.sublist(1).join('='),
        );
      }),
    );
    final frequency = parts['FREQ'];
    if (frequency != 'WEEKLY' && frequency != 'DAILY') {
      return const <LectureEvent>[];
    }
    final interval = int.tryParse(parts['INTERVAL'] ?? '1') ?? 1;
    final countLimit = int.tryParse(parts['COUNT'] ?? '');
    final until = _parseUntil(parts['UNTIL']) ?? windowEnd;
    final maxDate = until.isBefore(windowEnd) ? until : windowEnd;
    final byDays = _weekdays(parts['BYDAY'], event.start.weekday);
    final duration = event.end?.difference(event.start);
    final output = <LectureEvent>[];
    var generated = 0;
    var cursor = event.start;
    while (!cursor.isAfter(maxDate)) {
      final dayDistance = cursor
          .difference(
            DateTime(event.start.year, event.start.month, event.start.day),
          )
          .inDays;
      final intervalMatches = frequency == 'DAILY'
          ? dayDistance % interval == 0
          : (dayDistance ~/ 7) % interval == 0;
      if (intervalMatches && byDays.contains(cursor.weekday)) {
        generated += 1;
        if (countLimit != null && generated > countLimit) break;
        final occurrenceKey = cursor.microsecondsSinceEpoch;
        if (event.excludedStarts.contains(occurrenceKey) ||
            overriddenStarts.contains(occurrenceKey)) {
          cursor = cursor.add(const Duration(days: 1));
          continue;
        }
        final occurrence = event.copyWith(
          start: cursor,
          end: duration == null ? null : cursor.add(duration),
        );
        if (_overlaps(
          occurrence.start,
          occurrence.end,
          windowStart,
          windowEnd,
        )) {
          output.add(_lecture(occurrence, cursor));
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return output;
  }

  LectureEvent _lecture(_IcsEvent event, DateTime identityStart) {
    return LectureEvent(
      id: '${event.uid ?? event.title}-${identityStart.microsecondsSinceEpoch}',
      title: event.title,
      start: event.start,
      end: event.end,
      location: event.location,
      detail: event.detail,
    );
  }

  bool _overlaps(
    DateTime start,
    DateTime? end,
    DateTime windowStart,
    DateTime windowEnd,
  ) {
    final effectiveEnd = end == null || end.isBefore(start) ? start : end;
    return !start.isAfter(windowEnd) && !effectiveEnd.isBefore(windowStart);
  }
}

class _IcsEvent {
  const _IcsEvent({
    required this.title,
    required this.start,
    required this.end,
    required this.excludedStarts,
    required this.sequence,
    required this.isCancelled,
    this.uid,
    this.location,
    this.detail,
    this.rule,
    this.recurrenceId,
  });

  final String title;
  final DateTime start;
  final DateTime? end;
  final Set<int> excludedStarts;
  final int sequence;
  final bool isCancelled;
  final String? uid;
  final String? location;
  final String? detail;
  final String? rule;
  final DateTime? recurrenceId;

  _IcsEvent copyWith({required DateTime start, DateTime? end}) => _IcsEvent(
    title: title,
    start: start,
    end: end,
    excludedStarts: excludedStarts,
    uid: uid,
    location: location,
    detail: detail,
    rule: rule,
    recurrenceId: recurrenceId,
    sequence: sequence,
    isCancelled: isCancelled,
  );
}

String _overrideKey(String uid, DateTime recurrenceId) =>
    '$uid:${recurrenceId.microsecondsSinceEpoch}';
