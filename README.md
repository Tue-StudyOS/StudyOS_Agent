# StudyOS Agent

StudyOS Agent is a University of Tuebingen study assistant shell. The Flutter
app provides the cross-platform UI, while native runners expose platform
features such as Android services, sensors, speech/TTS, reminders, local model
execution, and iOS-safe native APIs where available.

## Install A Release

Use the public download page:

```text
https://tue-studyos.github.io/StudyOS_Agent/
```

Or open the GitHub Releases page directly:

```text
https://github.com/Tue-StudyOS/StudyOS_Agent/releases
```

Recommended artifacts:

- Android: download `studyos-agent-*-android.apk`, allow installs from your
  browser or file manager when Android asks, then open the APK.
- Web: download `studyos-agent-web-*.zip` for iOS, macOS, Windows, Linux, or any
  machine where installing a native app is inconvenient.
- Desktop: Linux, macOS, and Windows archives are available for packaging
  checks. macOS builds are not notarized yet, so Gatekeeper may block them.
- iOS: no direct installable build is published yet. Real iOS distribution
  needs Apple Developer Program signing and TestFlight.

Run the release web bundle locally:

```sh
unzip studyos-agent-web-*.zip -d studyos-agent-web
cd studyos-agent-web
python3 -m http.server 8080
```

Then open `http://127.0.0.1:8080`. Do not open `index.html` directly from disk;
Flutter web must be served by a web server.

## Run From Source

Requirements:

- Flutter stable with Dart 3.12 or newer
- Android Studio or Android SDK for Android builds
- Chrome for web development
- Xcode only when running iOS or macOS locally

Clone and start the Flutter app:

```sh
git clone https://github.com/Tue-StudyOS/StudyOS_Agent.git
cd StudyOS_Agent/flutter_app
flutter pub get
flutter run -d chrome
```

Useful run targets:

```sh
flutter run -d chrome
flutter run -d android
flutter run -d macos
```

Build release artifacts locally:

```sh
flutter build web --release
flutter build apk --release
```

Serve the local web build:

```sh
python3 -m http.server 8080 --directory build/web
```

## Assistant Model Setup

On first run, the app seeds a replaceable OpenRouter endpoint/model preset:

```text
Endpoint: https://openrouter.ai/api/v1/chat/completions
Model: nvidia/nemotron-3-ultra-550b-a55b:free
```

GitHub push protection blocks committing OpenRouter keys, so release builds do
not contain a default API key. Open `Settings -> Assistant setup -> Custom` and
paste an OpenRouter key, or build with the Dart define shown below. To avoid
cloud calls, switch `Assistant` back to `On device` and use the local model
controls.

On Android, the built-in setup checks the AICore Gemini Nano configurations
supported by the current device, preselects an available configuration, and can
request an AICore-managed model download. Unsupported configurations stay hidden;
if AICore is unavailable, settings show one compact unsupported status. Custom
LiteRT-LM URL downloads remain available in a collapsed advanced section. On iOS,
the built-in provider uses Apple Foundation Models when the device supports it.

For local development builds, you can override the seeded preset without editing
source:

```sh
flutter run -d chrome \
  --dart-define=STUDYOS_DEMO_OPENROUTER_ENDPOINT=https://openrouter.ai/api/v1/chat/completions \
  --dart-define=STUDYOS_DEMO_OPENROUTER_MODEL=nvidia/nemotron-3-ultra-550b-a55b:free \
  --dart-define=STUDYOS_DEMO_OPENROUTER_API_KEY="$OPENROUTER_API_KEY"
```

### Assistant tool privacy

StudyOS executes university tools in the app for both on-device and cloud
models. Portal credentials, cookies, SAML fields, session keys, and raw HTML
remain on the device. When a cloud model requests `get_tasks` or
`get_deadlines`, the app sends only the sanitized tool result (such as titles,
courses, dates, and source links) back to the configured AI service so it can
answer the question. Use the on-device model when those results must not leave
the device.

## Migration Notes

- Flutter owns the main chat UI, input bar, status display, navigation, and
  settings surfaces.
- Android native code is copied into the Flutter Android runner and exposed
  through `MethodChannel` and `EventChannel` bridge hooks.
- Android keeps OS-level integrations such as services, reminders, sensors, app
  launching, speech/TTS, and LiteRT/LiteRTLM.
- iOS exposes native location/device state, local notification reminders, speech
  availability, text-to-speech, and Apple Foundation Models when the SDK/device
  supports the Foundation Models framework.
- Web and desktop currently run the Flutter UI shell. Unsupported native bridge
  calls return explicit errors instead of mock data.
