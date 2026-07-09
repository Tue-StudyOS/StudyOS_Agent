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
      let rawLectures = args["lectures"] as? [Any]
    else {
      finish(result, flutterError("invalid_calendar_sync", "Expected lecture schedule arguments."))
      return
    }

    let sourceTerm = studyOSCalendarTrimmed(args["sourceTerm"]) ?? "ALMA"
    let lectures = rawLectures.compactMap(parseLecture)
    guard !lectures.isEmpty else {
      finish(result, flutterError("empty_calendar_sync", "No lectures were available to sync."))
      return
    }

    requestCalendarAccess { [weak self] error in
      guard let self else { return }
      if let error {
        finish(result, error)
        return
      }
      do {
        let message = try self.upsertLectures(lectures, sourceTerm: sourceTerm)
        finish(result, message)
      } catch {
        finish(result, flutterError("calendar_sync_failed", error.localizedDescription))
      }
    }
  }

  func listEvents(arguments: [String: Any], result: @escaping FlutterResult) {
    guard
      let start = studyOSCalendarParseIsoDate(studyOSCalendarTrimmed(arguments["start"]) ?? ""),
      let end = studyOSCalendarParseIsoDate(studyOSCalendarTrimmed(arguments["end"]) ?? ""),
      end > start
    else {
      finish(result, flutterError("invalid_calendar_window", "Expected valid ISO-8601 start and end."))
      return
    }

    let limit = min(max(studyOSCalendarIntValue(arguments["limit"]) ?? 25, 1), 50)
    requestCalendarAccess { [weak self] error in
      guard let self else { return }
      if let error {
        finish(result, error)
        return
      }
      let predicate = self.eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
      let events = self.eventStore.events(matching: predicate)
        .sorted { $0.startDate < $1.startDate }
        .prefix(limit)
      if events.isEmpty {
        self.finish(result, "No calendar events found in that time window.")
        return
      }
      let lines = events.map { event -> String in
        let location = studyOSCalendarOptionalSuffix(" @ ", event.location)
        return "- \(event.title ?? "Untitled"), \(studyOSCalendarDateLabel(event.startDate))-\(studyOSCalendarTimeLabel(event.endDate))\(location)"
      }
      self.finish(result, lines.joined(separator: "\n"))
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

  private func upsertLectures(_ lectures: [StudyOSCalendarLecture], sourceTerm: String) throws -> String {
    let calendar = try writableCalendar()
    let minStart = lectures.map(\.start).min()!.addingTimeInterval(-86_400)
    let maxEnd = lectures.map(\.end).max()!.addingTimeInterval(86_400)
    let predicate = eventStore.predicateForEvents(withStart: minStart, end: maxEnd, calendars: nil)
    var existingById: [String: EKEvent] = [:]
    for event in eventStore.events(matching: predicate) {
      if let id = lectureId(in: event.notes) {
        existingById[id] = event
      }
    }

    var created = 0
    var updated = 0
    for lecture in lectures {
      let event = existingById[lecture.id] ?? EKEvent(eventStore: eventStore)
      if existingById[lecture.id] == nil {
        event.calendar = calendar
        created += 1
      } else {
        updated += 1
      }
      event.title = lecture.title
      event.startDate = lecture.start
      event.endDate = lecture.end
      event.location = lecture.location
      event.notes = notes(for: lecture, sourceTerm: sourceTerm)
      try eventStore.save(event, span: .thisEvent)
    }

    return "Synced \(lectures.count) lecture events to \(calendar.title) (\(created) new, \(updated) updated)."
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
    let end = studyOSCalendarParseIsoDate(studyOSCalendarTrimmed(dict["end"]) ?? "") ?? start.addingTimeInterval(90 * 60)
    return StudyOSCalendarLecture(
      id: id,
      title: title,
      start: start,
      end: end,
      location: studyOSCalendarTrimmed(dict["location"]),
      detail: studyOSCalendarTrimmed(dict["detail"])
    )
  }

  private func notes(for lecture: StudyOSCalendarLecture, sourceTerm: String) -> String {
    var lines = [
      "\(markerPrefix) \(lecture.id)",
      "StudyOS term: \(sourceTerm)"
    ]
    if let detail = lecture.detail {
      lines.append("")
      lines.append(detail)
    }
    return lines.joined(separator: "\n")
  }

  private func lectureId(in notes: String?) -> String? {
    notes?
      .components(separatedBy: .newlines)
      .first { $0.hasPrefix(markerPrefix) }?
      .dropFirst(markerPrefix.count)
      .trimmingCharacters(in: .whitespacesAndNewlines)
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
