import Foundation

struct StudyOSIntentLecture: Codable {
  let id: String
  let title: String
  let start: String
  let end: String?
  let location: String?
  let detail: String?
}

struct StudyOSIntentSnapshot: Codable {
  let updatedAt: String
  let memoryPreview: String
  let lectures: [StudyOSIntentLecture]
}

final class StudyOSIntentSnapshotStore {
  static let shared = StudyOSIntentSnapshotStore()

  private init() {}

  func writeSnapshot(from arguments: Any?) throws {
    guard let dictionary = arguments as? [String: Any] else {
      throw SnapshotError.invalidPayload
    }
    let data = try JSONSerialization.data(
      withJSONObject: dictionary,
      options: [.prettyPrinted, .sortedKeys]
    )
    try FileManager.default.createDirectory(
      at: snapshotURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try data.write(to: snapshotURL, options: .atomic)
  }

  func readSnapshot() -> StudyOSIntentSnapshot? {
    guard FileManager.default.fileExists(atPath: snapshotURL.path) else {
      return nil
    }
    do {
      let data = try Data(contentsOf: snapshotURL)
      return try JSONDecoder().decode(StudyOSIntentSnapshot.self, from: data)
    } catch {
      return nil
    }
  }

  func nextLectureSummary() -> String {
    guard let snapshot = readSnapshot() else {
      return "No StudyOS timetable has been synced yet. Open StudyOS and refresh your schedule first."
    }

    let now = Date()
    let next = snapshot.lectures
      .compactMap { lecture -> (StudyOSIntentLecture, Date)? in
        guard let start = Self.parseDate(lecture.start), start >= now else {
          return nil
        }
        return (lecture, start)
      }
      .sorted { $0.1 < $1.1 }
      .first

    guard let (lecture, start) = next else {
      return "No upcoming StudyOS lectures were found in the synced timetable."
    }

    let dateText = Self.displayFormatter.string(from: start)
    let locationText = lecture.location.flatMap { $0.isEmpty ? nil : " at \($0)" } ?? ""
    return "\(lecture.title) starts \(dateText)\(locationText)."
  }

  func savePendingPrompt(_ prompt: String) throws {
    let cleaned = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else {
      try removePendingPrompt()
      return
    }
    try FileManager.default.createDirectory(
      at: pendingPromptURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try cleaned.write(to: pendingPromptURL, atomically: true, encoding: .utf8)
  }

  func consumePendingPrompt() throws -> String? {
    guard FileManager.default.fileExists(atPath: pendingPromptURL.path) else {
      return nil
    }
    let prompt = try String(contentsOf: pendingPromptURL, encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    try removePendingPrompt()
    return prompt.isEmpty ? nil : prompt
  }

  func appendMemory(_ text: String) throws {
    let cleaned = text
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return }

    var lines = try readMemoryLines()
    lines.append("- \(cleaned)")
    let content = "\(Self.trimmedMemory(lines).joined(separator: "\n"))\n"
    try FileManager.default.createDirectory(
      at: memoryURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try content.write(to: memoryURL, atomically: true, encoding: .utf8)
  }

  private func readMemoryLines() throws -> [String] {
    guard FileManager.default.fileExists(atPath: memoryURL.path) else {
      return []
    }
    return try String(contentsOf: memoryURL, encoding: .utf8)
      .split(separator: "\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private func removePendingPrompt() throws {
    if FileManager.default.fileExists(atPath: pendingPromptURL.path) {
      try FileManager.default.removeItem(at: pendingPromptURL)
    }
  }

  private var snapshotURL: URL {
    documentsURL.appendingPathComponent("studyos_intents_snapshot.json")
  }

  private var pendingPromptURL: URL {
    documentsURL.appendingPathComponent("studyos_pending_intent_prompt.txt")
  }

  private var memoryURL: URL {
    documentsURL.appendingPathComponent("studyos_memory.md")
  }

  private var documentsURL: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  }

  private static func trimmedMemory(_ lines: [String]) -> [String] {
    let maxLines = 240
    let maxCharacters = 48_000
    var next = lines.count > maxLines ? Array(lines.suffix(maxLines)) : lines
    while next.joined(separator: "\n").count > maxCharacters && next.count > 1 {
      next.removeFirst()
    }
    return next
  }

  private static func parseDate(_ value: String) -> Date? {
    if let date = fractionalFormatter.date(from: value) {
      return date
    }
    if let date = internetFormatter.date(from: value) {
      return date
    }
    for formatter in fallbackFormatters {
      if let date = formatter.date(from: value) {
        return date
      }
    }
    return nil
  }

  private static let internetFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  private static let fractionalFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let fallbackFormatters: [DateFormatter] = [
    "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
    "yyyy-MM-dd'T'HH:mm:ss.SSS",
    "yyyy-MM-dd'T'HH:mm:ss"
  ].map { pattern in
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = pattern
    return formatter
  }

  private static let displayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()

  enum SnapshotError: Error {
    case invalidPayload
  }
}
