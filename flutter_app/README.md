# StudyOS Agent Flutter Shell

This Flutter app is the cross-platform UI shell for StudyOS Agent. The Android
target keeps the existing Java native layer and exposes it to Flutter through
platform channels.

## Start Locally

```sh
flutter pub get
flutter run -d chrome
```

Other common targets:

```sh
flutter run -d android
flutter run -d macos
```

## Build Web

```sh
flutter build web --release
python3 -m http.server 8080 --directory build/web
```

Open `http://127.0.0.1:8080`. Serving the folder matters; opening
`build/web/index.html` directly is not supported by Flutter web.

## Model Preset

Fresh installs seed the assistant with the repository's OpenRouter endpoint and
model preset. GitHub push protection blocks committing OpenRouter keys, so users
still need to paste an API key in `Settings -> Assistant setup -> Custom` unless
the app was built with the Dart define below. Users can switch back to
`On device` for local model mode.

Android local mode probes the AICore Gemini Nano configurations supported by the
device and preselects an available one. Unsupported configurations are hidden,
while custom LiteRT-LM URL downloads remain available in a collapsed section.
iOS local mode continues to use Apple Foundation Models when supported.

For development builds, override the seeded preset with Dart defines:

```sh
flutter run -d chrome \
  --dart-define=STUDYOS_DEMO_OPENROUTER_ENDPOINT=https://openrouter.ai/api/v1/chat/completions \
  --dart-define=STUDYOS_DEMO_OPENROUTER_MODEL=nvidia/nemotron-3-ultra-550b-a55b:free \
  --dart-define=STUDYOS_DEMO_OPENROUTER_API_KEY="$OPENROUTER_API_KEY"
```

## Course Ratings

Course lookup, ratings, and comments use the repository's containerized service.
It proxies the public StudyPlanner catalog so Flutter web does not depend on the
catalog's browser CORS policy. Point the app at an HTTPS deployment at build
time; plain HTTP is accepted only for a loopback development endpoint:

```sh
flutter run -d chrome \
  --dart-define=STUDYOS_FEEDBACK_API_URL=https://feedback.example.edu
```

The endpoint is public configuration, not a secret. Open **Course ratings** in
the secondary navigation, search by title/number, and select a result. The
service creates a
pseudonymous installation token on first submission, and the app stores it with
`flutter_secure_storage` for later updates, deletion, and reports. Never put the
service's moderator token or a GitHub credential in a Dart define.

## Native Bridge

The current bridge initializes native Android managers, routes Android messages
into the copied `JarvisController`, and exposes capability/world-state data.
The iOS bridge exposes native location/device state, notification reminders,
speech availability, text-to-speech, and Apple Foundation Models responses
when the current SDK/device supports the `FoundationModels` framework.

Unsupported native features should return explicit platform errors rather than
mock responses.
