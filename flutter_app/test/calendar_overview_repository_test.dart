import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyos_agent/src/calendar_overview_repository.dart';
import 'package:studyos_agent/src/native_bridge.dart';
import 'package:studyos_agent/src/talks_client.dart';
import 'package:studyos_agent/src/talks_repository.dart';

void main() {
  test('calendar overview reports a truncated device event result', () async {
    final bridge = _BusyCalendarBridge();
    final talks = TalksRepository(
      client: TalksClient(
        httpClient: MockClient(
          (_) async => http.Response(jsonEncode({'talks': <Object?>[]}), 200),
        ),
      ),
    );
    addTearDown(talks.dispose);

    final snapshot = await CalendarOverviewRepository(
      bridge,
      talks,
    ).load(start: DateTime(2026, 7, 1), end: DateTime(2026, 11, 1));

    expect(bridge.requestedLimit, 251);
    expect(snapshot.deviceEvents, hasLength(250));
    expect(snapshot.deviceCalendarTruncated, isTrue);
  });
}

class _BusyCalendarBridge extends NativeBridge {
  int? requestedLimit;

  @override
  Future<List<Map<String, Object?>>> listDeviceCalendarEvents({
    required DateTime start,
    required DateTime end,
    int limit = 250,
  }) async {
    requestedLimit = limit;
    return List<Map<String, Object?>>.generate(limit, (index) {
      final eventStart = start.add(Duration(hours: index));
      return <String, Object?>{
        'id': 'event-$index',
        'title': 'Event $index',
        'start': eventStart.toIso8601String(),
        'end': eventStart.add(const Duration(hours: 1)).toIso8601String(),
        'calendarName': 'Calendar',
        'allDay': false,
      };
    });
  }
}
