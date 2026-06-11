import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class SessionStore {
  SessionStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _sessionsKey = 'studyos.chat.sessions.v1';
  static const String _activeSessionKey = 'studyos.chat.activeSessionId.v1';

  final SharedPreferencesAsync _preferences;

  Future<SessionState> load() async {
    final encodedSessions = await _preferences.getString(_sessionsKey);
    final activeSessionId = await _preferences.getString(_activeSessionKey);
    final sessions = ChatSession.decodeList(encodedSessions);

    if (sessions.isEmpty) {
      final fresh = ChatSession.fresh();
      await save(sessions: <ChatSession>[fresh], activeSessionId: fresh.id);
      return SessionState(
        sessions: <ChatSession>[fresh],
        activeSessionId: fresh.id,
      );
    }

    final activeExists = sessions.any(
      (session) => session.id == activeSessionId,
    );
    return SessionState(
      sessions: sessions,
      activeSessionId: activeExists ? activeSessionId! : sessions.first.id,
    );
  }

  Future<void> save({
    required List<ChatSession> sessions,
    required String activeSessionId,
  }) async {
    await _preferences.setString(
      _sessionsKey,
      ChatSession.encodeList(sessions),
    );
    await _preferences.setString(_activeSessionKey, activeSessionId);
  }
}

class SessionState {
  const SessionState({required this.sessions, required this.activeSessionId});

  final List<ChatSession> sessions;
  final String activeSessionId;
}
