import 'dart:convert';

class DeviceCalendarEvent {
  const DeviceCalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.isAllDay,
    required this.calendarName,
    this.location,
    this.notes,
  });

  static const String studyOsMarker = 'StudyOS lecture id:';

  final String id;
  final String title;
  final DateTime start;
  final DateTime? end;
  final bool isAllDay;
  final String calendarName;
  final String? location;
  final String? notes;

  String? get studyOsLectureId {
    final value = notes;
    if (value == null) return null;
    for (final line in value.split(RegExp(r'\r?\n'))) {
      if (!line.startsWith(studyOsMarker)) continue;
      final id = line.substring(studyOsMarker.length).trim();
      if (id.isNotEmpty) return id;
    }
    return null;
  }

  static DeviceCalendarEvent? fromMap(Map<String, Object?> map) {
    final notes = _text(map['notes']);
    final isStudyOsManaged =
        notes
            ?.split(RegExp(r'\r?\n'))
            .any((line) => line.startsWith(studyOsMarker)) ??
        false;
    String managedText(String value) =>
        isStudyOsManaged ? _repairLegacyUtf8(value) : value;
    final title = managedText(map['title']?.toString().trim() ?? '');
    final start = _date(map['start']);
    if (title.isEmpty || start == null) return null;
    final id = map['id']?.toString().trim();
    final calendarName = map['calendarName']?.toString().trim();
    final location = _text(map['location']);
    return DeviceCalendarEvent(
      id: id?.isNotEmpty == true
          ? id!
          : '$title-${start.microsecondsSinceEpoch}',
      title: title,
      start: start,
      end: _date(map['end']),
      isAllDay: map['allDay'] == true,
      calendarName: calendarName?.isNotEmpty == true
          ? calendarName!
          : 'Calendar',
      location: location == null ? null : managedText(location),
      notes: notes == null ? null : managedText(notes),
    );
  }
}

DateTime? _date(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed?.toLocal();
}

String? _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

String _repairLegacyUtf8(String value) {
  if (!value.contains(RegExp(r'[ÃÂâ]'))) return value;
  try {
    return utf8.decode(latin1.encode(value));
  } on FormatException {
    return value;
  } on ArgumentError {
    return value;
  }
}
