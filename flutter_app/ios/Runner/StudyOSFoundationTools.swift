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
  let description = "Read the current StudyOS profile, memory, and local device context before answering."

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
  let description = "Read the local long-term StudyOS memory document before answering."

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
#endif
