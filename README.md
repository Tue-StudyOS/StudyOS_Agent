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
- iOS, web, and desktop currently run as limited shells until platform
  adapters are implemented.

Run the migration shell with:

```sh
cd flutter_app
flutter run
```

The first migration PR is intentionally a bridge-first implementation. It
does not rewrite every Android service in Dart because many current features
are Android-specific and should stay behind native adapters.
