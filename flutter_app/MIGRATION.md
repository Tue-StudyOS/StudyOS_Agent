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
  - message forwarding into the native storage layer

## Capability matrix

| Capability | Android | iOS | Web/Desktop |
| --- | --- | --- | --- |
| Flutter chat UI | yes | yes | yes |
| Native event channel | yes | not yet | not yet |
| World-state provider | yes | not yet | limited |
| Exact alarms/reminders | yes | limited | no |
| Always-listening service | Android-specific | heavily restricted | no |
| App/package launching | Android-specific | limited | no |
| Flashlight/system tools | yes | limited | no |
| LiteRT/LiteRTLM offline engine | Android copied native layer | not yet | no |

## Next implementation steps

1. Refactor `JarvisController` and brain classes so responses are emitted
   through a small callback/event interface instead of directly touching
   Android XML UI classes.
2. Change the Android `sendMessage` bridge to call that controller interface
   and stream assistant responses back to Flutter.
3. Move portable DTOs and memory contracts to Dart only after the bridge is
   stable.
4. Add Swift adapters for realistic iOS capabilities such as local
   notifications, speech/TTS, and location.
5. Keep Android-only tools visible through `getCapabilities()` so the Flutter
   UI can disable unavailable commands per platform.

## Non-goals for this branch

- Full iOS parity for Android assistant behavior.
- Rewriting Android services in Dart.
- Moving credentials or university authentication through hosted services.
- Replacing the existing offline model engine.
