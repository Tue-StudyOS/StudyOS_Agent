import AVFoundation
import CoreLocation
import Flutter
import Speech
import UIKit
import UserNotifications

final class StudyOSNativeBridge: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private let locationManager = CLLocationManager()
  private let speechSynthesizer = AVSpeechSynthesizer()
  private var eventSink: FlutterEventSink?
  private var lastLocation: CLLocation?

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
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    methodChannel.setMethodCallHandler(handle)
    eventChannel.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    emitStatus("Native iOS event channel connected.")
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    lastLocation = locations.last
    if let location = lastLocation {
      emitStatus("iOS location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    emitStatus("iOS location failed: \(error.localizedDescription)")
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      initialize(result: result)
    case "getWorldState":
      result(worldState())
    case "getCapabilities":
      result(capabilities())
    case "executeNativeTool":
      executeNativeTool(call: call, result: result)
    case "publishIntentSnapshot":
      publishIntentSnapshot(call: call, result: result)
    case "consumePendingIntentPrompt":
      consumePendingIntentPrompt(result: result)
    case "sendMessage":
      guard
        let args = call.arguments as? [String: Any],
        let text = args["text"] as? String,
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        result(FlutterError(code: "empty_message", message: "Message text must not be empty.", details: nil))
        return
      }
      let prompt = args["systemPrompt"] as? String
      let memory = args["memory"] as? String
      respondToMessage(
        text.trimmingCharacters(in: .whitespacesAndNewlines),
        systemPrompt: prompt,
        memory: memory,
        result: result
      )
    case "createReminder":
      createReminder(call: call, result: result)
    case "speak":
      speak(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func publishIntentSnapshot(call: FlutterMethodCall, result: FlutterResult) {
    do {
      try StudyOSIntentSnapshotStore.shared.writeSnapshot(from: call.arguments)
      result("iOS intent snapshot published.")
    } catch {
      result(FlutterError(
        code: "intent_snapshot_write_failed",
        message: error.localizedDescription,
        details: nil
      ))
    }
  }

  private func consumePendingIntentPrompt(result: FlutterResult) {
    do {
      result(try StudyOSIntentSnapshotStore.shared.consumePendingPrompt())
    } catch {
      result(FlutterError(
        code: "intent_prompt_read_failed",
        message: error.localizedDescription,
        details: nil
      ))
    }
  }

  private func initialize(result: @escaping FlutterResult) {
    UIDevice.current.isBatteryMonitoringEnabled = true
    locationManager.requestWhenInUseAuthorization()
    locationManager.requestLocation()

    SFSpeechRecognizer.requestAuthorization { [weak self] status in
      DispatchQueue.main.async {
        self?.emitStatus("iOS native bridge initialized.")
        result([
          "status": "iOS native bridge initialized.",
          "speechAuthorization": self?.speechStatusName(status) ?? "unknown",
          "locationAuthorization": self?.locationAuthorizationName() ?? "unknown"
        ])
      }
    }
  }

  private func respondToMessage(
    _ text: String,
    systemPrompt: String?,
    memory: String?,
    result: @escaping FlutterResult
  ) {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      StudyOSFoundationResponder.respond(
        text: text,
        systemPrompt: systemPrompt,
        memory: memory,
        emitToolTrace: emitToolTrace,
        emitStatus: emitStatus,
        result: result
      )
      return
    }
    #endif

    result(FlutterError(
      code: "llm_unavailable",
      message: "Apple Foundation Models are unavailable on this device or SDK. Native iOS LLM requires iOS 26+ with FoundationModels support.",
      details: nil
    ))
  }

  private func createReminder(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let title = args["title"] as? String,
      let seconds = args["secondsFromNow"] as? Double
    else {
      result(FlutterError(code: "invalid_reminder", message: "Expected title and secondsFromNow.", details: nil))
      return
    }

    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
      if let error = error {
        result(FlutterError(code: "notification_permission_error", message: error.localizedDescription, details: nil))
        return
      }
      guard granted else {
        result(FlutterError(code: "notification_permission_denied", message: "Notification permission denied.", details: nil))
        return
      }

      let content = UNMutableNotificationContent()
      content.title = title
      content.sound = .default
      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
      let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
      UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
          result(FlutterError(code: "notification_schedule_error", message: error.localizedDescription, details: nil))
        } else {
          result("iOS reminder scheduled.")
        }
      }
    }
  }

  private func speak(call: FlutterMethodCall, result: FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let text = args["text"] as? String,
      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      result(FlutterError(code: "empty_speech", message: "Speech text must not be empty.", details: nil))
      return
    }

    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
    speechSynthesizer.speak(utterance)
    result("iOS speech started.")
  }

  private func executeNativeTool(call: FlutterMethodCall, result: FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let name = args["name"] as? String
    else {
      result(FlutterError(code: "native_tool_missing_name", message: "Native tool name is required.", details: nil))
      return
    }

    result(FlutterError(
      code: "native_tool_unsupported",
      message: "Native tool is not supported on iOS in this build: \(name).",
      details: nil
    ))
  }

  private func worldState() -> [String: Any] {
    var state: [String: Any] = [
      "platform": "ios",
      "systemName": UIDevice.current.systemName,
      "systemVersion": UIDevice.current.systemVersion,
      "deviceModel": UIDevice.current.model,
      "batteryLevel": UIDevice.current.batteryLevel,
      "batteryState": batteryStateName(),
      "locationAuthorization": locationAuthorizationName(),
      "speechRecognitionAvailable": SFSpeechRecognizer(locale: Locale.current)?.isAvailable ?? false
    ]

    if let location = lastLocation {
      state["gps"] = "\(location.coordinate.latitude), \(location.coordinate.longitude)"
      state["horizontalAccuracy"] = location.horizontalAccuracy
      state["locationTimestamp"] = ISO8601DateFormatter().string(from: location.timestamp)
    } else {
      state["locationStatus"] = "No location fix yet."
    }

    return state
  }

  private func capabilities() -> [String: Any] {
    var values: [String: Any] = [
      "platform": "ios",
      "canUseAlwaysListeningService": false,
      "canUseBackgroundLocation": false,
      "canCreateExactAlarm": false,
      "canOpenInstalledApps": false,
      "canReadCalendar": false,
      "canUseOfflineLiteRtModel": false,
      "canControlFlashlight": false,
      "canStartPhoneCall": true,
      "canUseSpeechRecognition": SFSpeechRecognizer(locale: Locale.current)?.isAvailable ?? false,
      "canUseTextToSpeech": true,
      "canCreateLocalNotificationReminder": true,
      "canUseAppIntents": canUseAppIntents()
    ]
    values["nativeToolContractVersion"] = 1
    values["nativeTools"] = nativeToolCapabilities()

    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      values["canUseAppleFoundationModels"] = true
    } else {
      values["canUseAppleFoundationModels"] = false
      values["foundationModelsReason"] = "Requires iOS 26+."
    }
    #else
    values["canUseAppleFoundationModels"] = false
    values["foundationModelsReason"] = "FoundationModels framework is unavailable in this SDK."
    #endif

    return values
  }

  private func nativeToolCapabilities() -> [[String: Any]] {
    let iosControlReason = "This native control is Android-only in this build."
    return [
      ["name": "get_device_status", "supported": false, "reason": iosControlReason],
      ["name": "set_flashlight", "supported": false, "reason": iosControlReason],
      ["name": "open_installed_app", "supported": false, "reason": "iOS does not support arbitrary installed-app launching from this app."],
      ["name": "search_youtube", "supported": false, "reason": iosControlReason],
      ["name": "open_system_setting", "supported": false, "reason": iosControlReason],
      ["name": "create_reminder", "supported": false, "reason": "Reminder tool exposure is reserved for the reminder PR."]
    ]
  }

  private func canUseAppIntents() -> Bool {
    #if canImport(AppIntents)
    if #available(iOS 16.0, *) {
      return true
    }
    #endif
    return false
  }

  private func emitToolTrace(toolName: String, status: String, summary: String, callId: String) {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?([
        "type": "toolTrace",
        "message": "\(toolName) \(status)",
        "timestamp": ISO8601DateFormatter().string(from: Date()),
        "trace": [
          "toolName": toolName,
          "status": status,
          "summary": summary,
          "callId": callId
        ]
      ])
    }
  }

  private func emitStatus(_ message: String) {
    eventSink?([
      "type": "status",
      "message": message,
      "timestamp": ISO8601DateFormatter().string(from: Date())
    ])
  }

  private func speechStatusName(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
    switch status {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "notDetermined"
    @unknown default: return "unknown"
    }
  }

  private func locationAuthorizationName() -> String {
    let status: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      status = locationManager.authorizationStatus
    } else {
      status = CLLocationManager.authorizationStatus()
    }

    switch status {
    case .authorizedAlways: return "authorizedAlways"
    case .authorizedWhenInUse: return "authorizedWhenInUse"
    case .denied: return "denied"
    case .notDetermined: return "notDetermined"
    case .restricted: return "restricted"
    @unknown default: return "unknown"
    }
  }

  private func batteryStateName() -> String {
    switch UIDevice.current.batteryState {
    case .charging: return "charging"
    case .full: return "full"
    case .unplugged: return "unplugged"
    case .unknown: return "unknown"
    @unknown default: return "unknown"
    }
  }
}
