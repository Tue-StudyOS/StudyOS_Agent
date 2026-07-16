import 'package:flutter/services.dart';

import 'device_calendar_event.dart';
import 'native_bridge.dart';
import 'talk_models.dart';
import 'talks_repository.dart';

class CalendarOverviewSnapshot {
  const CalendarOverviewSnapshot({
    required this.talks,
    required this.deviceEvents,
    this.talksError,
    this.deviceCalendarError,
    this.deviceCalendarTruncated = false,
  });

  static const empty = CalendarOverviewSnapshot(
    talks: <Talk>[],
    deviceEvents: <DeviceCalendarEvent>[],
  );

  final List<Talk> talks;
  final List<DeviceCalendarEvent> deviceEvents;
  final String? talksError;
  final String? deviceCalendarError;
  final bool deviceCalendarTruncated;
}

abstract interface class CalendarOverviewSource {
  Future<CalendarOverviewSnapshot> load({
    required DateTime start,
    required DateTime end,
    bool refreshTalks = false,
  });
}

class CalendarOverviewRepository implements CalendarOverviewSource {
  const CalendarOverviewRepository(this._bridge, this._talksRepository);

  static const int _deviceEventLimit = 250;

  final NativeBridge _bridge;
  final TalksRepository _talksRepository;

  @override
  Future<CalendarOverviewSnapshot> load({
    required DateTime start,
    required DateTime end,
    bool refreshTalks = false,
  }) async {
    var talks = const <Talk>[];
    var deviceEvents = const <DeviceCalendarEvent>[];
    String? talksError;
    String? deviceCalendarError;
    var deviceCalendarTruncated = false;

    await Future.wait<void>(<Future<void>>[
      () async {
        try {
          talks = await _talksRepository.load(refresh: refreshTalks);
        } on Object catch (error) {
          talksError = error.toString();
        }
      }(),
      () async {
        try {
          final rawEvents = await _bridge.listDeviceCalendarEvents(
            start: start,
            end: end,
            limit: _deviceEventLimit + 1,
          );
          deviceCalendarTruncated = rawEvents.length > _deviceEventLimit;
          deviceEvents = rawEvents
              .take(_deviceEventLimit)
              .map(DeviceCalendarEvent.fromMap)
              .whereType<DeviceCalendarEvent>()
              .toList();
        } on Object catch (error) {
          deviceCalendarError = _calendarError(error);
        }
      }(),
    ]);

    return CalendarOverviewSnapshot(
      talks: talks,
      deviceEvents: deviceEvents,
      talksError: talksError,
      deviceCalendarError: deviceCalendarError,
      deviceCalendarTruncated: deviceCalendarTruncated,
    );
  }
}

String _calendarError(Object error) {
  if (error is MissingPluginException) {
    return 'Device calendar access is not supported on this platform.';
  }
  if (error is PlatformException) {
    final message = error.message?.trim();
    return message?.isNotEmpty == true
        ? message!
        : 'Calendar access failed (${error.code}).';
  }
  return error.toString();
}
