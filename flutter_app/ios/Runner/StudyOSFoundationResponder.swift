import Flutter
import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
enum StudyOSFoundationResponder {
  static func respond(
    text: String,
    systemPrompt: String?,
    memory: String?,
    emitToolTrace: @escaping (String, String, String, String) -> Void,
    emitStatus: @escaping (String) -> Void,
    result: @escaping FlutterResult
  ) {
    Task {
      do {
        let context = systemPrompt ?? "No StudyOS context was provided."
        let memoryText = memory?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let recorder = LocalToolCallRecorder()
        let tools: [any Tool] = [
          StudyContextTool(context: context, recorder: recorder, emit: emitToolTrace),
          ReadMemoriesTool(memory: memoryText, recorder: recorder, emit: emitToolTrace)
        ]
        let session = LanguageModelSession(
          tools: tools,
          instructions: systemPrompt ?? "You are StudyOS Agent. Answer concisely and helpfully."
        )
        let response = try await session.respond(to: text)
        guard recorder.hasCalls else {
          await MainActor.run {
            result(FlutterError(
              code: "local_tools_missing",
              message: "Apple Foundation Models returned without calling a StudyOS tool. Try again or switch to a cloud model for stricter tool-call control.",
              details: nil
            ))
          }
          return
        }
        await MainActor.run {
          emitStatus("Apple Foundation Models response received.")
          result(response.content)
        }
      } catch {
        await MainActor.run {
          result(FlutterError(
            code: "foundation_models_error",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }
}
#endif
