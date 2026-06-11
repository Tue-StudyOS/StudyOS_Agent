# StudyOS Agent Flutter Shell

This Flutter app is the cross-platform UI shell for the StudyOS Agent
migration. The Android target keeps the existing Java native layer and exposes
it to Flutter through platform channels.

```sh
flutter run
```

The current bridge initializes native Android managers, routes Android messages
into the copied `JarvisController`, and exposes capability/world-state data.
The iOS bridge exposes native location/device state, notification reminders,
speech availability, text-to-speech, and Apple Foundation Models responses
when the current SDK/device supports the `FoundationModels` framework.

Unsupported native features should return explicit platform errors rather than
mock responses.
