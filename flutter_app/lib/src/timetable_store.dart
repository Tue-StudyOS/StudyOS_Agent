import 'package:shared_preferences/shared_preferences.dart';

import 'timetable_models.dart';

class TimetableStore {
  TimetableStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _snapshotKey = 'studyos.timetable.snapshot.v2';

  final SharedPreferencesAsync _preferences;

  Future<TimetableSnapshot?> load() async {
    final encoded = await _preferences.getString(_snapshotKey);
    if (encoded == null || encoded.isEmpty) return null;
    return TimetableSnapshot.decode(encoded);
  }

  Future<void> save(TimetableSnapshot snapshot) {
    return _preferences.setString(_snapshotKey, snapshot.encode());
  }

  Future<void> clear() {
    return _preferences.remove(_snapshotKey);
  }
}
