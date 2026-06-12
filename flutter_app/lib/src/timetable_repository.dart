import 'alma_timetable_client.dart';
import 'models.dart';
import 'profile_store.dart';
import 'timetable_store.dart';

class TimetableRepository {
  TimetableRepository({
    ProfileStore? profileStore,
    TimetableStore? timetableStore,
  }) : _profileStore = profileStore ?? ProfileStore(),
       _timetableStore = timetableStore ?? TimetableStore();

  final ProfileStore _profileStore;
  final TimetableStore _timetableStore;

  Future<TimetableSnapshot?> load() {
    return _timetableStore.load();
  }

  Future<TimetableSnapshot> refresh(OnboardingProfile profile) async {
    final password = await _profileStore.readPassword();
    if (password == null || password.isEmpty) {
      throw const AlmaTimetableException(
        'Sign in again to refresh your timetable.',
      );
    }
    final client = AlmaTimetableClient();
    try {
      final snapshot = await client.fetch(
        username: profile.username,
        password: password,
      );
      await _timetableStore.save(snapshot);
      return snapshot;
    } finally {
      client.close();
    }
  }
}
