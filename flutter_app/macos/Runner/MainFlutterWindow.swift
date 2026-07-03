import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var nativeBridge: MacOSNativeBridge?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    nativeBridge = MacOSNativeBridge(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

final class MacOSNativeBridge: NSObject, FlutterStreamHandler {
  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private var eventSink: FlutterEventSink?

  init(messenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(
      name: "studyos/native",
      binaryMessenger: messenger
    )
    eventChannel = FlutterEventChannel(
      name: "studyos/events",
      binaryMessenger: messenger
    )
    super.init()
    methodChannel.setMethodCallHandler(handle)
    eventChannel.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    emitStatus("Native macOS event channel connected.")
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      emitStatus("Native macOS bridge initialized.")
      result(["status": "Native macOS bridge initialized."])
    case "getWorldState":
      result(worldState())
    case "getCapabilities":
      result(capabilities())
    case "getNativeToolCapabilities":
      result(nativeToolCapabilityMap())
    case "listLocalModels":
      result([])
    case "downloadLocalModel":
      result(FlutterError(
        code: "local_model_unavailable",
        message: "Local model downloads are not supported on macOS in this build.",
        details: nil
      ))
    case "cancelLocalModelDownload", "deleteLocalModel":
      result(nil)
    case "publishIntentSnapshot":
      result("macOS intent snapshot ignored.")
    case "consumePendingIntentPrompt":
      result(nil)
    case "sendMessage":
      result(FlutterError(
        code: "llm_unavailable",
        message: "Native macOS LLM is not supported in this build. Configure a cloud provider in Assistant setup.",
        details: nil
      ))
    case "cancelMessage":
      result(nil)
    case "executeNativeTool":
      executeNativeTool(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func executeNativeTool(call: FlutterMethodCall, result: FlutterResult) {
    let name = (call.arguments as? [String: Any])?["name"] as? String ?? "unknown"
    result(FlutterError(
      code: "native_tool_unsupported",
      message: "Native tool is not supported on macOS in this build: \(name).",
      details: nil
    ))
  }

  private func worldState() -> [String: Any] {
    let version = ProcessInfo.processInfo.operatingSystemVersion
    return [
      "platform": "macos",
      "systemName": "macOS",
      "systemVersion": "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
      "deviceModel": Host.current().localizedName ?? "Mac",
      "locationStatus": "Location is unavailable on macOS in this build."
    ]
  }

  private func capabilities() -> [String: Any] {
    var values: [String: Any] = [
      "platform": "macos",
      "canUseAlwaysListeningService": false,
      "canUseBackgroundLocation": false,
      "canCreateExactAlarm": false,
      "canOpenInstalledApps": false,
      "canReadCalendar": false,
      "canUseOfflineLiteRtModel": false,
      "canControlFlashlight": false,
      "canStartPhoneCall": false,
      "canUseSpeechRecognition": false,
      "canUseTextToSpeech": false,
      "canCreateLocalNotificationReminder": false,
      "canUseAppIntents": false,
      "canUseAppleFoundationModels": false,
      "foundationModelsReason": "Native macOS LLM is not supported in this build.",
      "nativeToolContractVersion": 1
    ]
    values["nativeTools"] = nativeToolCapabilities()
    return values
  }

  private func nativeToolCapabilityMap() -> [String: Any] {
    return [
      "platform": "macos",
      "nativeToolContractVersion": 1,
      "nativeTools": nativeToolCapabilities()
    ]
  }

  private func nativeToolCapabilities() -> [[String: Any]] {
    let reason = "This native control is unavailable on macOS in this build."
    return [
      ["name": "get_device_status", "supported": false, "reason": reason],
      ["name": "set_flashlight", "supported": false, "reason": reason],
      ["name": "open_installed_app", "supported": false, "reason": reason],
      ["name": "search_youtube", "supported": false, "reason": reason],
      ["name": "open_system_setting", "supported": false, "reason": reason],
      ["name": "create_reminder", "supported": false, "reason": reason]
    ]
  }

  private func emitStatus(_ message: String) {
    eventSink?([
      "type": "status",
      "message": message,
      "timestamp": ISO8601DateFormatter().string(from: Date())
    ])
  }
}
