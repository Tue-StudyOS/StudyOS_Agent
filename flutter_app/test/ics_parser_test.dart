import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/ics_parser.dart';
import 'package:studyos_agent/src/timetable_models.dart';

void main() {
  test('parses recurring ALMA lectures from iCalendar', () {
    const ics = '''
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:alma-1
SUMMARY:AI for Scientific Discovery
DTSTART;TZID=Europe/Berlin:20260617T180000
DTEND;TZID=Europe/Berlin:20260617T200000
LOCATION:Room 01, Morgenstelle
RRULE:FREQ=WEEKLY;COUNT=2;BYDAY=WE
END:VEVENT
END:VCALENDAR
''';

    final events = const IcsParser().parseUpcoming(
      ics,
      now: DateTime(2026, 6, 12),
    );

    expect(events, hasLength(2));
    expect(events.first.title, 'AI for Scientific Discovery');
    expect(events.first.timeRangeText, '18:00 - 20:00');
    expect(events.first.location, 'Room 01, Morgenstelle');
    expect(events.last.start.day, 24);
  });
}
