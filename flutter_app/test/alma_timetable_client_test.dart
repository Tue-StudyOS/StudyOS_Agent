import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyos_agent/src/alma_timetable_client.dart';
import 'package:studyos_agent/src/ics_parser.dart';
import 'package:studyos_agent/src/timetable_models.dart';

void main() {
  test('decodes ALMA iCalendar bytes as UTF-8 without a charset', () async {
    final parser = _RecordingIcsParser();
    final client = AlmaTimetableClient(
      icsParser: parser,
      httpClient: MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            '<body class="loggedin">Signed in</body>',
            200,
            request: request,
          );
        }
        if (request.url.path.endsWith('hisinoneStartPage.faces')) {
          return http.Response(
            '''
<form id="loginForm" action="/alma/login">
  <input name="asdf"><input name="fdsa" type="password">
</form>
''',
            200,
            request: request,
          );
        }
        if (request.url.path.endsWith('individualTimetable.xhtml')) {
          return http.Response(
            '''
<select name="plan:scheduleConfiguration:anzeigeoptionen:changeTerm_input">
  <option value="20261" selected>Sommer 2026</option>
</select>
<textarea name="plan:scheduleConfiguration:anzeigeoptionen:ical:cal_add">/alma/calendar.ics</textarea>
''',
            200,
            request: request,
          );
        }
        if (request.url.path.endsWith('calendar.ics')) {
          return http.Response.bytes(
            utf8.encode('''
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:unicode
SUMMARY:ML4202 Übung
DTSTART:20260723T100000
LOCATION:Hörsaal A2, Wilhelmstraße 19
END:VEVENT
END:VCALENDAR
'''),
            200,
            headers: const <String, String>{'content-type': 'text/calendar'},
            request: request,
          );
        }
        return http.Response('Not found', 404, request: request);
      }),
    );
    addTearDown(client.close);

    final snapshot = await client.fetch(
      username: 'student',
      password: 'secret',
    );

    expect(parser.rawIcs, contains('ML4202 Übung'));
    expect(parser.rawIcs, contains('Hörsaal A2, Wilhelmstraße 19'));
    expect(parser.rawIcs, isNot(contains('Ã')));
    expect(parser.now, snapshot.refreshedAt);
  });
}

class _RecordingIcsParser extends IcsParser {
  String? rawIcs;
  DateTime? now;

  @override
  List<LectureEvent> parseUpcoming(String rawIcs, {DateTime? now}) {
    this.rawIcs = rawIcs;
    this.now = now;
    return const <LectureEvent>[];
  }
}
