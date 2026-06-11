# StudyOS Agent

This is an agent for the University of Tuebingen.

## Flutter migration

The repository now contains a Flutter migration shell in `flutter_app/`.
The existing native Android Java project remains in place while the Flutter
app becomes the new cross-platform UI experiment.

Current migration shape:

- Flutter owns the main chat UI, input bar, status display, and capability
  drawer.
- Android native code is copied into the Flutter Android runner and exposed
  through `MethodChannel`/`EventChannel` bridge hooks.
- Android keeps OS-level integrations such as services, reminders, sensors,
  app launching, speech/TTS, and LiteRT/LiteRTLM.
- iOS registers the same native bridge and exposes iOS-safe native APIs for
  location-backed world state, local notification reminders, speech
  availability, text-to-speech, and Apple Foundation Models when the SDK/device
  supports the Foundation Models framework.
- Web and desktop currently run the Flutter UI shell only; unsupported native
  bridge calls return explicit errors instead of mock data.

Run the migration shell with:

```sh
cd flutter_app
flutter run
```

The first migration PR is intentionally a bridge-first implementation. It
does not rewrite every Android service in Dart because many current features
are Android-specific and should stay behind native adapters.
