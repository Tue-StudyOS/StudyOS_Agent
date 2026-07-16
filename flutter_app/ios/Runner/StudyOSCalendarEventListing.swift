import EventKit
import Foundation

private let studyOSCalendarReadQueue = DispatchQueue(
  label: "com.studyos.calendar-read",
  qos: .userInitiated
)

func studyOSReadCalendarEvents(
  in eventStore: EKEventStore,
  arguments: [String: Any],
  maximumLimit: Int,
  completion: @escaping (Result<[EKEvent], Error>) -> Void
) {
  studyOSCalendarReadQueue.async {
    do {
      completion(.success(try studyOSCalendarEvents(
        in: eventStore,
        arguments: arguments,
        maximumLimit: maximumLimit
      )))
    } catch {
      completion(.failure(error))
    }
  }
}

func studyOSCalendarEvents(
  in eventStore: EKEventStore,
  arguments: [String: Any],
  maximumLimit: Int
) throws -> [EKEvent] {
  guard
    let start = studyOSCalendarParseIsoDate(studyOSCalendarTrimmed(arguments["start"]) ?? ""),
    let end = studyOSCalendarParseIsoDate(studyOSCalendarTrimmed(arguments["end"]) ?? ""),
    end > start
  else {
    throw StudyOSCalendarBridgeError("Expected valid ISO-8601 start and end.")
  }
  let limit = min(
    max(studyOSCalendarIntValue(arguments["limit"]) ?? 25, 1),
    maximumLimit
  )
  let predicate = eventStore.predicateForEvents(
    withStart: start,
    end: end,
    calendars: nil
  )
  return Array(
    eventStore.events(matching: predicate)
      .sorted { $0.startDate < $1.startDate }
      .prefix(limit)
  )
}

func studyOSCalendarEventListText(_ events: [EKEvent]) -> String {
  guard !events.isEmpty else {
    return "No calendar events found in that time window."
  }
  return events.map { event -> String in
    let location = studyOSCalendarOptionalSuffix(" @ ", event.location)
    return "- \(event.title ?? "Untitled"), \(studyOSCalendarDateLabel(event.startDate))-\(studyOSCalendarTimeLabel(event.endDate))\(location)"
  }.joined(separator: "\n")
}

func studyOSCalendarEventMap(_ event: EKEvent) -> [String: Any] {
  let identifier = event.eventIdentifier ?? event.calendarItemIdentifier
  var value: [String: Any] = [
    "id": "\(identifier):\(studyOSCalendarIsoString(event.startDate))",
    "title": event.title ?? "Untitled",
    "start": studyOSCalendarIsoString(event.startDate),
    "end": studyOSCalendarIsoString(event.endDate),
    "allDay": event.isAllDay,
    "calendarName": event.calendar.title
  ]
  if let location = studyOSCalendarTrimmed(event.location) {
    value["location"] = location
  }
  if let notes = studyOSCalendarTrimmed(event.notes) {
    value["notes"] = notes
  }
  return value
}

private func studyOSCalendarIsoString(_ date: Date) -> String {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return formatter.string(from: date)
}
