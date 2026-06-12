import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
final class LocalToolCallRecorder {
  private let lock = NSLock()
  private var count = 0

  var hasCalls: Bool {
    lock.lock()
    defer { lock.unlock() }
    return count > 0
  }

  func recordCall() {
    lock.lock()
    count += 1
    lock.unlock()
  }
}

@available(iOS 26.0, *)
final class StudyContextTool: Tool {
  let name = "get_study_context"
  let description = "Read current profile, memory, and local study context."

  @Generable
  struct Arguments {}

  private let context: String
  private let recorder: LocalToolCallRecorder
  private let emit: (String, String, String, String) -> Void

  init(
    context: String,
    recorder: LocalToolCallRecorder,
    emit: @escaping (String, String, String, String) -> Void
  ) {
    self.context = context
    self.recorder = recorder
    self.emit = emit
  }

  func call(arguments: Arguments) async throws -> String {
    recorder.recordCall()
    let callId = "local-get-study-context-\(UUID().uuidString)"
    emit(name, "running", "Reading StudyOS context.", callId)
    emit(name, "done", "Returned \(context.count) chars.", callId)
    return context
  }
}

@available(iOS 26.0, *)
final class ReadMemoriesTool: Tool {
  let name = "read_memories"
  let description = "Read the local long-term memory document."

  @Generable
  struct Arguments {}

  private let memory: String
  private let recorder: LocalToolCallRecorder
  private let emit: (String, String, String, String) -> Void

  init(
    memory: String,
    recorder: LocalToolCallRecorder,
    emit: @escaping (String, String, String, String) -> Void
  ) {
    self.memory = memory
    self.recorder = recorder
    self.emit = emit
  }

  func call(arguments: Arguments) async throws -> String {
    recorder.recordCall()
    let callId = "local-read-memories-\(UUID().uuidString)"
    emit(name, "running", "Reading local memories.", callId)
    let output = memory.isEmpty ? "No saved StudyOS memories." : memory
    emit(name, "done", "Returned \(output.count) chars.", callId)
    return output
  }
}

@available(iOS 26.0, *)
final class AppendMemoryTool: Tool {
  let name = "append_memory"
  let description = "Append a durable student memory to local device storage."

  @Generable
  struct Arguments {
    var text: String
  }

  private let store: LocalMemoryDocumentStore
  private let recorder: LocalToolCallRecorder
  private let emit: (String, String, String, String) -> Void

  init(
    store: LocalMemoryDocumentStore,
    recorder: LocalToolCallRecorder,
    emit: @escaping (String, String, String, String) -> Void
  ) {
    self.store = store
    self.recorder = recorder
    self.emit = emit
  }

  func call(arguments: Arguments) async throws -> String {
    recorder.recordCall()
    let callId = "local-append-memory-\(UUID().uuidString)"
    emit(name, "running", "Writing local memory.", callId)
    let size = try store.append(arguments.text)
    emit(name, "done", "Memory document is \(size) chars.", callId)
    return "Memory saved."
  }
}

final class LocalMemoryDocumentStore {
  private let maxLines = 240
  private let maxCharacters = 48_000

  func append(_ text: String) throws -> Int {
    let cleaned = text
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return try read().count }

    var lines = try readLines()
    lines.append("- \(cleaned)")
    let next = trimmed(lines)
    let content = "\(next.joined(separator: "\n"))\n"
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try content.write(to: fileURL, atomically: true, encoding: .utf8)
    return content.count
  }

  private func read() throws -> String {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return ""
    }
    return try String(contentsOf: fileURL, encoding: .utf8)
  }

  private func readLines() throws -> [String] {
    try read()
      .split(separator: "\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private func trimmed(_ lines: [String]) -> [String] {
    var next = lines.count > maxLines
      ? Array(lines.suffix(maxLines))
      : lines
    while next.joined(separator: "\n").count > maxCharacters && next.count > 1 {
      next.removeFirst()
    }
    return next
  }

  private var fileURL: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("studyos_memory.md")
  }
}
#endif
