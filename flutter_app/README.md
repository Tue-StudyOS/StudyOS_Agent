# StudyOS Agent Flutter Shell

This Flutter app is the cross-platform UI shell for the StudyOS Agent
migration. The Android target keeps the existing Java native layer and exposes
it to Flutter through platform channels.

```sh
flutter run
```

The current bridge is intentionally conservative: it initializes native Android
managers, exposes capability/world-state data, and forwards messages into the
native storage layer. The next step is to refactor the Java controller/brain
classes so assistant responses are streamed back into Flutter instead of being
coupled to the old Android XML UI.
