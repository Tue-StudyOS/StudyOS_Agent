import EventKit
import Foundation

struct StudyOSCalendarLecture {
  let id: String
  let title: String
  let start: Date
  let end: Date
  let location: String?
  let detail: String?
}

enum StudyOSCalendarAccess {
  case available
  case promptable
  case unavailable(String)

  var canAttempt: Bool {
    switch self {
    case .available, .promptable: return true
    case .unavailable: return false
    }
  }

  var unsupportedReason: String? {
    switch self {
    case .available, .promptable: return nil
    case .unavailable(let reason): return reason
    }
  }
}

struct StudyOSCalendarBridgeError: LocalizedError {
  let errorDescription: String?

  init(_ message: String) {
    errorDescription = message
  }
}

func studyOSCalendarParseIsoDate(_ value: String) -> Date? {
  let fractional = ISO8601DateFormatter()
  fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  if let date = fractional.date(from: value) {
    return date
  }
  if let date = ISO8601DateFormatter().date(from: value) {
    return date
  }
  return studyOSCalendarParseLocalIsoDate(value)
}

private func studyOSCalendarParseLocalIsoDate(_ value: String) -> Date? {
  let formatter = DateFormatter()
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.timeZone = .current
  for format in [
    "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
    "yyyy-MM-dd'T'HH:mm:ss.SSS",
    "yyyy-MM-dd'T'HH:mm:ss"
  ] {
    formatter.dateFormat = format
    if let date = formatter.date(from: value) {
      return date
    }
  }
  return nil
}

func studyOSCalendarDateLabel(_ date: Date) -> String {
  let formatter = DateFormatter()
  formatter.dateFormat = "EEE d MMM HH:mm"
  return formatter.string(from: date)
}

func studyOSCalendarTimeLabel(_ date: Date) -> String {
  let formatter = DateFormatter()
  formatter.dateFormat = "HH:mm"
  return formatter.string(from: date)
}

func studyOSCalendarOptionalSuffix(_ prefix: String, _ value: String?) -> String {
  guard let value = studyOSCalendarTrimmed(value) else { return "" }
  return "\(prefix)\(value)"
}

func studyOSCalendarWritableSource(_ eventStore: EKEventStore) -> EKSource? {
  if let source = eventStore.defaultCalendarForNewEvents?.source {
    return source
  }
  if let local = eventStore.sources.first(where: { $0.sourceType == .local }) {
    return local
  }
  return eventStore.sources.first {
    $0.sourceType != .birthdays && $0.sourceType != .subscribed
  }
}

func studyOSCalendarTrimmed(_ value: Any?) -> String? {
  let text = studyOSCalendarStringValue(value)?
    .trimmingCharacters(in: .whitespacesAndNewlines)
  return text?.isEmpty == false ? text : nil
}

func studyOSCalendarIntValue(_ value: Any?) -> Int? {
  if let value = value as? Int { return value }
  if let value = value as? NSNumber { return value.intValue }
  return Int(studyOSCalendarStringValue(value) ?? "")
}

private func studyOSCalendarStringValue(_ value: Any?) -> String? {
  if let string = value as? String { return string }
  guard let value else { return nil }
  return "\(value)"
}
