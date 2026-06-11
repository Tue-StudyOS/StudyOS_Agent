# Flutter Migration Notes

## Implemented in this branch

- A generated Flutter app lives in `flutter_app/`.
- `lib/main.dart` implements the StudyOS Agent chat shell.
- The Flutter shell talks to native code over:
  - `MethodChannel("studyos/native")`
  - `EventChannel("studyos/events")`
- The Android runner keeps the copied Java native layer under
  `android/app/src/main/java/com/example/studyOS`.
- The Android launcher is now a Flutter activity with bridge methods for:
  - native initialization
  - world-state snapshots
  - capability reporting
  - message forwarding into the copied `JarvisController`
- The iOS runner now registers the same bridge in
  `didInitializeImplicitFlutterEngine` and exposes native iOS APIs for:
  - world-state snapshots from `UIDevice` and `CoreLocation`
  - capability reporting
  - local notification reminders
  - text-to-speech via `AVSpeechSynthesizer`
  - speech-recognition authorization and availability
  - Apple Foundation Models responses when built with an SDK/device that
    supports the `FoundationModels` framework

## Capability matrix

| Capability | Android | iOS | Web/Desktop |
| --- | --- | --- | --- |
| Flutter chat UI | yes | yes | shell only |
| Native event channel | yes | yes | no native adapter |
| World-state provider | yes | yes, device/location subset | no native adapter |
| Exact alarms/reminders | yes | local notification reminders | no native adapter |
| Always-listening service | Android-specific | heavily restricted | no |
| App/package launching | Android-specific | limited | no |
| Flashlight/system tools | yes | limited | no |
| LiteRT/LiteRTLM offline engine | Android copied native layer | not yet | no |
| Native LLM | LiteRT/LiteRTLM path copied from Android | Foundation Models when available | no native adapter |

Unsupported platform methods should return explicit native errors. The Flutter
layer should not invent fake capability data or mock assistant responses.

## Next implementation steps

1. Refactor `JarvisController` and brain classes so responses are emitted
   through a small callback/event interface instead of directly touching
   Android XML UI classes.
2. Stream Android assistant responses back to Flutter from the copied
   controller/brain layer.
3. Move portable DTOs and memory contracts to Dart only after the bridge is
   stable.
4. Expand Swift adapters for full speech input and additional iOS-safe tools.
5. Keep Android-only tools visible through `getCapabilities()` so the Flutter
   UI can disable unavailable commands per platform.

## Non-goals for this branch

- Full iOS parity for Android assistant behavior.
- Rewriting Android services in Dart.
- Moving credentials or university authentication through hosted services.
- Replacing the existing offline model engine.
