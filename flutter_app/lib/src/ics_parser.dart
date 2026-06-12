import 'timetable_models.dart';

class IcsParser {
  const IcsParser();

  List<LectureEvent> parseUpcoming(String rawIcs, {DateTime? now}) {
    final windowStart = now ?? DateTime.now();
    final windowEnd = windowStart.add(const Duration(days: 120));
    final events = _events(rawIcs);
    final expanded = <LectureEvent>[];
    for (final event in events) {
      expanded.addAll(_expand(event, windowStart, windowEnd));
    }
    expanded.sort((a, b) => a.start.compareTo(b.start));
    return expanded;
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
    final start = fields['DTSTART']?.firstOrNull;
    final startDate = start == null ? null : _parseDate(start);
    if (startDate == null) return null;
    final end = fields['DTEND']?.firstOrNull;
    return _IcsEvent(
      uid: _text(fields['UID']?.firstOrNull),
      title: _text(fields['SUMMARY']?.firstOrNull) ?? 'Untitled lecture',
      start: startDate,
      end: end == null ? null : _parseDate(end),
      location: _text(fields['LOCATION']?.firstOrNull),
      detail: _text(fields['DESCRIPTION']?.firstOrNull),
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
    DateTime windowEnd,
  ) {
    final rule = event.rule;
    if (rule == null || rule.isEmpty) {
      return _overlaps(event.start, event.end, windowStart, windowEnd)
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
      if (intervalMatches &&
          byDays.contains(cursor.weekday) &&
          !event.excludedStarts.contains(cursor.microsecondsSinceEpoch)) {
        generated += 1;
        if (countLimit != null && generated > countLimit) break;
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

  LectureEvent _lecture(_IcsEvent event, DateTime start) {
    return LectureEvent(
      id: '${event.uid ?? event.title}-${start.microsecondsSinceEpoch}',
      title: event.title,
      start: start,
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

class _IcsProperty {
  const _IcsProperty({
    required this.name,
    required this.parameters,
    required this.value,
  });

  final String name;
  final Map<String, String> parameters;
  final String value;

  _IcsProperty copyWith({String? value}) => _IcsProperty(
    name: name,
    parameters: parameters,
    value: value ?? this.value,
  );
}

class _IcsEvent {
  const _IcsEvent({
    required this.title,
    required this.start,
    required this.end,
    required this.excludedStarts,
    this.uid,
    this.location,
    this.detail,
    this.rule,
  });

  final String title;
  final DateTime start;
  final DateTime? end;
  final Set<int> excludedStarts;
  final String? uid;
  final String? location;
  final String? detail;
  final String? rule;

  _IcsEvent copyWith({required DateTime start, DateTime? end}) => _IcsEvent(
    title: title,
    start: start,
    end: end,
    excludedStarts: excludedStarts,
    uid: uid,
    location: location,
    detail: detail,
    rule: rule,
  );
}

List<String> _unfold(String raw) {
  final lines = <String>[];
  for (final line
      in raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
    if ((line.startsWith(' ') || line.startsWith('\t')) && lines.isNotEmpty) {
      lines[lines.length - 1] = '${lines.last}${line.substring(1)}';
    } else {
      lines.add(line);
    }
  }
  return lines;
}

_IcsProperty? _parseLine(String line) {
  final separator = line.indexOf(':');
  if (separator < 1) return null;
  final keyParts = line.substring(0, separator).split(';');
  final parameters = <String, String>{};
  for (final part in keyParts.skip(1)) {
    final split = part.split('=');
    if (split.length == 2) parameters[split.first.toUpperCase()] = split.last;
  }
  return _IcsProperty(
    name: keyParts.first.toUpperCase(),
    parameters: parameters,
    value: line.substring(separator + 1),
  );
}

DateTime? _parseDate(_IcsProperty property) =>
    _parseIcsDate(property.value, property.parameters);

DateTime? _parseUntil(String? value) =>
    value == null ? null : _parseIcsDate(value, const <String, String>{});

DateTime? _parseIcsDate(String value, Map<String, String> parameters) {
  final raw = value.trim();
  if (raw.length == 8 || parameters['VALUE'] == 'DATE') {
    return DateTime.tryParse(
      '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)}',
    );
  }
  final year = int.tryParse(raw.substring(0, 4));
  final month = int.tryParse(raw.substring(4, 6));
  final day = int.tryParse(raw.substring(6, 8));
  final hour = raw.length >= 11 ? int.tryParse(raw.substring(9, 11)) : 0;
  final minute = raw.length >= 13 ? int.tryParse(raw.substring(11, 13)) : 0;
  final second = raw.length >= 15 ? int.tryParse(raw.substring(13, 15)) : 0;
  if ([year, month, day, hour, minute, second].contains(null)) return null;
  if (raw.endsWith('Z')) {
    return DateTime.utc(year!, month!, day!, hour!, minute!, second!).toLocal();
  }
  return DateTime(year!, month!, day!, hour!, minute!, second!);
}

String? _text(_IcsProperty? property) {
  final value = property?.value;
  if (value == null || value.isEmpty) return null;
  return value
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\N', '\n')
      .replaceAll(r'\,', ',')
      .replaceAll(r'\;', ';')
      .replaceAll(r'\\', r'\')
      .trim();
}

Set<int> _weekdays(String? raw, int fallback) {
  const map = <String, int>{
    'MO': 1,
    'TU': 2,
    'WE': 3,
    'TH': 4,
    'FR': 5,
    'SA': 6,
    'SU': 7,
  };
  if (raw == null || raw.isEmpty) return <int>{fallback};
  return raw
      .split(',')
      .map((day) => map[day.substring(day.length - 2).toUpperCase()])
      .whereType<int>()
      .toSet();
}
