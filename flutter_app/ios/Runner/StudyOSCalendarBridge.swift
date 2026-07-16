import EventKit
import Flutter
import Foundation

final class StudyOSCalendarBridge {
  private let eventStore = EKEventStore()
  private let markerPrefix = "StudyOS lecture id:"
  private let calendarTitle = "StudyOS"

  func capabilityValues() -> [String: Any] {
    let canAttempt = calendarAccess().canAttempt
    return [
      "canReadCalendar": canAttempt,
      "canCreateCalendarEvents": canAttempt,
      "canSyncScheduleToCalendar": canAttempt
    ]
  }

  func calendarToolSupport(name: String) -> [String: Any] {
    let access = calendarAccess()
    var support: [String: Any] = [
      "name": name,
      "supported": access.canAttempt
    ]
    if let reason = access.unsupportedReason {
      support["reason"] = reason
    }
    return support
  }

  func syncSchedule(arguments: Any?, result: @escaping FlutterResult) {
    guard
      let args = arguments as? [String: Any],
      let rawLectures = args["lectures"] as? [Any],
      let windowStart = studyOSCalendarParseIsoDate(
        studyOSCalendarTrimmed(args["windowStart"]) ?? ""
      ),
      let windowEnd = studyOSCalendarParseIsoDate(
        studyOSCalendarTrimmed(args["windowEnd"]) ?? ""
      ),
      windowEnd > windowStart
    else {
      finish(result, flutterError("invalid_calendar_sync", "Expected lecture schedule arguments."))
      return
    }

    let sourceTerm = studyOSCalendarTrimmed(args["sourceTerm"]) ?? "ALMA"
    let lectures = rawLectures.compactMap(parseLecture)
    guard lectures.count == rawLectures.count else {
      finish(result, flutterError("invalid_calendar_sync", "One or more lectures were invalid."))
      return
    }

    requestCalendarAccess { [weak self] error in
      guard let self else { return }
      if let error {
        finish(result, error)
        return
      }
      do {
        let message = try self.upsertLectures(
          lectures,
          sourceTerm: sourceTerm,
          windowStart: windowStart,
          windowEnd: windowEnd
        )
        finish(result, message)
      } catch {
        finish(result, flutterError("calendar_sync_failed", error.localizedDescription))
      }
    }
  }

  func listEvents(arguments: [String: Any], result: @escaping FlutterResult) {
    requestCalendarAccess { [weak self] error in
      guard let self else { return }
      if let error {
        finish(result, error)
        return
      }
      studyOSReadCalendarEvents(
        in: self.eventStore, arguments: arguments, maximumLimit: 50
      ) { eventResult in
        switch eventResult {
        case .success(let events):
          self.finish(result, studyOSCalendarEventListText(events))
        case .failure(let error):
          self.finish(result, self.flutterError("invalid_calendar_window", error.localizedDescription))
        }
      }
    }
  }

  func listStructuredEvents(arguments: Any?, result: @escaping FlutterResult) {
    guard let arguments = arguments as? [String: Any] else {
      finish(result, flutterError("invalid_calendar_window", "Expected calendar window arguments."))
      return
    }
    requestCalendarAccess { [weak self] error in
      guard let self else { return }
      if let error {
        finish(result, error)
        return
      }
      studyOSReadCalendarEvents(
        in: self.eventStore, arguments: arguments, maximumLimit: 500
      ) { eventResult in
        switch eventResult {
        case .success(let events):
          self.finish(result, events.map(studyOSCalendarEventMap))
        case .failure(let error):
          self.finish(result, self.flutterError("invalid_calendar_window", error.localizedDescription))
        }
      }
    }
  }

  func createEvent(arguments: [String: Any], result: @escaping FlutterResult) {
    guard
      let title = studyOSCalendarTrimmed(arguments["title"]),
      let start = studyOSCalendarParseIsoDate(studyOSCalendarTrimmed(arguments["start"]) ?? ""),
      let end = studyOSCalendarParseIsoDate(studyOSCalendarTrimmed(arguments["end"]) ?? ""),
      end > start
    else {
      finish(result, flutterError("invalid_calendar_event", "Expected title plus valid ISO-8601 start and end."))
      return
    }

    requestCalendarAccess { [weak self] error in
      guard let self else { return }
      if let error {
        finish(result, error)
        return
      }
      guard let calendar = try? self.writableCalendar() else {
        self.finish(result, self.flutterError("calendar_unavailable", "No writable calendar is available."))
        return
      }
      let event = EKEvent(eventStore: self.eventStore)
      event.calendar = calendar
      event.title = title
      event.startDate = start
      event.endDate = end
      event.location = studyOSCalendarTrimmed(arguments["location"])
      event.notes = studyOSCalendarTrimmed(arguments["notes"])
      do {
        try self.eventStore.save(event, span: .thisEvent)
        self.finish(result, "Created calendar event '\(title)' for \(studyOSCalendarDateLabel(start)).")
      } catch {
        self.finish(result, self.flutterError("calendar_create_failed", error.localizedDescription))
      }
    }
  }

  private func upsertLectures(
    _ lectures: [StudyOSCalendarLecture],
    sourceTerm: String,
    windowStart: Date,
    windowEnd: Date
  ) throws -> String {
    let calendar = try writableCalendar()
    return try studyOSSyncLectures(
      in: eventStore,
      calendar: calendar,
      lectures: lectures,
      sourceTerm: sourceTerm,
      markerPrefix: markerPrefix,
      windowStart: windowStart,
      windowEnd: windowEnd
    )
  }

  private func writableCalendar() throws -> EKCalendar {
    if let calendar = eventStore.calendars(for: .event).first(where: {
      $0.title == calendarTitle && $0.allowsContentModifications
    }) {
      return calendar
    }
    if let defaultCalendar = eventStore.defaultCalendarForNewEvents,
       defaultCalendar.allowsContentModifications {
      return defaultCalendar
    }
    guard let source = studyOSCalendarWritableSource(eventStore) else {
      throw StudyOSCalendarBridgeError("No writable calendar source is available.")
    }
    let calendar = EKCalendar(for: .event, eventStore: eventStore)
    calendar.title = calendarTitle
    calendar.source = source
    try eventStore.saveCalendar(calendar, commit: true)
    return calendar
  }

  private func requestCalendarAccess(_ completion: @escaping (FlutterError?) -> Void) {
    switch calendarAccess() {
    case .available:
      completion(nil)
    case .promptable:
      if #available(iOS 17.0, *) {
        eventStore.requestFullAccessToEvents { granted, error in
          completion(self.accessResult(granted: granted, error: error))
        }
      } else {
        eventStore.requestAccess(to: .event) { granted, error in
          completion(self.accessResult(granted: granted, error: error))
        }
      }
    case .unavailable(let reason):
      completion(flutterError("calendar_permission_unavailable", reason))
    }
  }

  private func accessResult(granted: Bool, error: Error?) -> FlutterError? {
    if let error {
      return flutterError("calendar_permission_error", error.localizedDescription)
    }
    return granted ? nil : flutterError("calendar_permission_denied", "Calendar access was denied.")
  }

  private func calendarAccess() -> StudyOSCalendarAccess {
    let status = EKEventStore.authorizationStatus(for: .event)
    if #available(iOS 17.0, *) {
      switch status {
      case .fullAccess, .authorized:
        return .available
      case .writeOnly:
        return .unavailable("Full calendar access is required to read and sync events.")
      case .notDetermined:
        return .promptable
      case .denied:
        return .unavailable("Calendar access is denied in Settings.")
      case .restricted:
        return .unavailable("Calendar access is restricted on this device.")
      @unknown default:
        return .unavailable("Calendar access status is unknown.")
      }
    }

    switch status {
    case .fullAccess, .authorized:
      return .available
    case .writeOnly:
      return .unavailable("Full calendar access is required to read and sync events.")
    case .notDetermined:
      return .promptable
    case .denied:
      return .unavailable("Calendar access is denied in Settings.")
    case .restricted:
      return .unavailable("Calendar access is restricted on this device.")
    @unknown default:
      return .unavailable("Calendar access status is unknown.")
    }
  }

  private func parseLecture(_ item: Any) -> StudyOSCalendarLecture? {
    guard
      let dict = item as? [String: Any],
      let title = studyOSCalendarTrimmed(dict["title"]),
      let start = studyOSCalendarParseIsoDate(studyOSCalendarTrimmed(dict["start"]) ?? "")
    else {
      return nil
    }
    let id = studyOSCalendarTrimmed(dict["id"]) ?? "\(title)-\(Int(start.timeIntervalSince1970))"
    let sourceIds = (dict["sourceIds"] as? [Any])?
      .compactMap(studyOSCalendarTrimmed) ?? []
    let end = studyOSCalendarParseIsoDate(studyOSCalendarTrimmed(dict["end"]) ?? "") ?? start.addingTimeInterval(90 * 60)
    return StudyOSCalendarLecture(
      id: id,
      sourceIds: sourceIds,
      title: title,
      start: start,
      end: end,
      location: studyOSCalendarTrimmed(dict["location"]),
      detail: studyOSCalendarTrimmed(dict["detail"])
    )
  }

  private func flutterError(_ code: String, _ message: String) -> FlutterError {
    FlutterError(code: code, message: message, details: nil)
  }

  private func finish(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async {
      result(value)
    }
  }
}
