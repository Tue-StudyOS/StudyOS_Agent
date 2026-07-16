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
LOCATION:Hörsaal 01, Wilhelmstraße 19
DESCRIPTION:Übung
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
    expect(events.first.location, 'Hörsaal 01, Wilhelmstraße 19');
    expect(events.first.detail, 'Übung');
    expect(events.last.start.day, 24);
  });

  test('detached overrides replace and cancel recurring occurrences', () {
    const ics = '''
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:series-1
SUMMARY:Probabilistic Machine Learning
DTSTART;TZID=Europe/Berlin:20260702T100000
DTEND;TZID=Europe/Berlin:20260702T120000
DESCRIPTION:Vorlesung
RRULE:FREQ=WEEKLY;COUNT=3;BYDAY=TH
END:VEVENT
BEGIN:VEVENT
UID:series-1
RECURRENCE-ID;TZID=Europe/Berlin:20260709T100000
SEQUENCE:2
SUMMARY:Probabilistic Machine Learning
DTSTART;TZID=Europe/Berlin:20260710T110000
DTEND;TZID=Europe/Berlin:20260710T140000
DESCRIPTION:Klausur
END:VEVENT
BEGIN:VEVENT
UID:series-1
RECURRENCE-ID;TZID=Europe/Berlin:20260716T100000
SEQUENCE:1
STATUS:CANCELLED
SUMMARY:Probabilistic Machine Learning
END:VEVENT
END:VCALENDAR
''';

    final events = const IcsParser().parseUpcoming(
      ics,
      now: DateTime(2026, 7, 1),
    );

    expect(events, hasLength(2));
    expect(events.first.start, DateTime(2026, 7, 2, 10));
    final exam = events.last;
    expect(exam.start, DateTime(2026, 7, 10, 11));
    expect(exam.end, DateTime(2026, 7, 10, 14));
    expect(exam.detail, 'Klausur');
    expect(
      exam.id,
      'series-1-${DateTime(2026, 7, 9, 10).microsecondsSinceEpoch}',
      reason: 'A moved override keeps the recurring occurrence identity.',
    );
  });

  test('coalesces room allocations but keeps different session types', () {
    const events = <String>[
      '''
BEGIN:VEVENT
UID:room-c
SUMMARY:ML4202 Probabilistic Machine Learning
DTSTART:20260723T100000
DTEND:20260723T130000
LOCATION:Hörsaal A2 (A-223) Cyber Valley Campus, MVL1
DESCRIPTION:Klausur
END:VEVENT''',
      '''
BEGIN:VEVENT
UID:room-a
SUMMARY:ML4202 Probabilistic Machine Learning
DTSTART:20260723T100000
DTEND:20260723T130000
LOCATION:Seminarraum A-207 Cyber Valley Campus, MVL1
DESCRIPTION:Klausur
END:VEVENT''',
      '''
BEGIN:VEVENT
UID:room-b
SUMMARY:ML4202 Probabilistic Machine Learning
DTSTART:20260723T100000
DTEND:20260723T130000
LOCATION:Hörsaal A1 (A-206) Cyber Valley Campus, MVL1
DESCRIPTION:Klausur
END:VEVENT''',
      '''
BEGIN:VEVENT
UID:lecture
SUMMARY:ML4202 Probabilistic Machine Learning
DTSTART:20260723T100000
DTEND:20260723T120000
LOCATION:Hörsaal A2 (A-223) Cyber Valley Campus, MVL1
DESCRIPTION:Vorlesung
END:VEVENT''',
    ];

    List<LectureEvent> parse(Iterable<String> source) =>
        const IcsParser().parseUpcoming(
          'BEGIN:VCALENDAR\n${source.join('\n')}\nEND:VCALENDAR',
          now: DateTime(2026, 7, 1),
        );

    final parsed = parse(events);
    final reversed = parse(events.reversed);

    expect(parsed, hasLength(2));
    final exam = parsed.singleWhere((event) => event.detail == 'Klausur');
    expect(exam.sourceIds, hasLength(2));
    expect(exam.location, startsWith('3 locations · Cyber Valley Campus'));
    expect(exam.location, contains('Hörsaal A1 (A-206)'));
    expect(exam.location, contains('Hörsaal A2 (A-223)'));
    expect(exam.location, contains('Seminarraum A-207'));
    expect(
      reversed.map((event) => event.toJson()),
      parsed.map((event) => event.toJson()),
      reason: 'Input order must not change canonical merged occurrences.',
    );
  });
}
