import 'dart:convert';

class LectureEvent {
  const LectureEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.location,
    this.detail,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime? end;
  final String? location;
  final String? detail;

  bool get isNow {
    final now = DateTime.now();
    final effectiveEnd = end ?? start.add(const Duration(minutes: 90));
    return !now.isBefore(start) && !now.isAfter(effectiveEnd);
  }

  String get dayKey => _dayKey(start);

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'start': start.toIso8601String(),
    'end': end?.toIso8601String(),
    'location': location,
    'detail': detail,
  };

  static LectureEvent? fromJson(Map<String, Object?> json) {
    final title = json['title']?.toString().trim();
    final start = DateTime.tryParse(json['start']?.toString() ?? '');
    if (title == null || title.isEmpty || start == null) return null;
    return LectureEvent(
      id: json['id']?.toString() ?? '$title-${start.microsecondsSinceEpoch}',
      title: title,
      start: start,
      end: DateTime.tryParse(json['end']?.toString() ?? ''),
      location: _optional(json['location']),
      detail: _optional(json['detail']),
    );
  }
}

class TimetableSnapshot {
  const TimetableSnapshot({
    required this.refreshedAt,
    required this.sourceTerm,
    required this.events,
  });

  final DateTime refreshedAt;
  final String sourceTerm;
  final List<LectureEvent> events;

  bool get isStale =>
      DateTime.now().difference(refreshedAt) > const Duration(hours: 4);

  List<LectureEvent> get upcoming {
    final now = DateTime.now().subtract(const Duration(minutes: 15));
    return events.where((event) => event.start.isAfter(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  LectureEvent? get nextLecture => upcoming.isEmpty ? null : upcoming.first;

  List<DateTime> get days {
    final starts =
        events.map((event) => _dateOnly(event.start)).toSet().toList()..sort();
    return starts;
  }

  List<LectureEvent> eventsOn(DateTime day) {
    final key = _dayKey(day);
    return events.where((event) => event.dayKey == key).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  String compactSummary({int limit = 5}) {
    if (events.isEmpty) return 'No cached timetable entries.';
    final lines = <String>[
      'Source term: $sourceTerm',
      'Last refreshed: ${refreshedAt.toIso8601String()}',
      'Upcoming lectures:',
      for (final event in upcoming.take(limit))
        '- ${event.title}, ${event.timeRangeText}${event.location == null ? '' : ', ${event.location}'}',
    ];
    return lines.join('\n');
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'refreshedAt': refreshedAt.toIso8601String(),
    'sourceTerm': sourceTerm,
    'events': events.map((event) => event.toJson()).toList(),
  };

  String encode() => jsonEncode(toJson());

  static TimetableSnapshot? decode(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) return null;
    final json = Map<String, Object?>.from(decoded);
    final refreshedAt = DateTime.tryParse(
      json['refreshedAt']?.toString() ?? '',
    );
    final sourceTerm = json['sourceTerm']?.toString().trim();
    final rawEvents = json['events'];
    if (refreshedAt == null ||
        sourceTerm == null ||
        sourceTerm.isEmpty ||
        rawEvents is! List) {
      return null;
    }
    return TimetableSnapshot(
      refreshedAt: refreshedAt,
      sourceTerm: sourceTerm,
      events:
          rawEvents
              .whereType<Map>()
              .map(
                (item) =>
                    LectureEvent.fromJson(Map<String, Object?>.from(item)),
              )
              .whereType<LectureEvent>()
              .toList()
            ..sort((a, b) => a.start.compareTo(b.start)),
    );
  }
}

extension LectureEventFormatting on LectureEvent {
  String get timeRangeText {
    final startText = _time(start);
    final endText = end == null ? null : _time(end!);
    return endText == null ? startText : '$startText - $endText';
  }

  String get dayLabel {
    const weekdays = <int, String>{
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
    };
    return '${weekdays[start.weekday] ?? 'Day'} ${start.day}.${start.month}.';
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _dayKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String? _optional(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
