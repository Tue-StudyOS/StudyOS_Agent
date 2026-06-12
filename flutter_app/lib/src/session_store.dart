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
    final sessions = ChatSession.decodeList(
      encodedSessions,
    ).where((session) => session.hasTurns).toList();

    if (sessions.isEmpty) {
      await _preferences.remove(_sessionsKey);
      await _preferences.remove(_activeSessionKey);
      final fresh = ChatSession.fresh();
      return SessionState(
        sessions: <ChatSession>[fresh],
        activeSessionId: fresh.id,
      );
    }

    final activeExists = sessions.any(
      (session) => session.id == activeSessionId,
    );
    await save(
      sessions: sessions,
      activeSessionId: activeExists ? activeSessionId! : sessions.first.id,
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
    final persistedSessions = sessions.where((session) => session.hasTurns);
    if (persistedSessions.isEmpty) {
      await _preferences.remove(_sessionsKey);
      await _preferences.remove(_activeSessionKey);
      return;
    }
    final nextSessions = persistedSessions.toList();
    final nextActiveId =
        nextSessions.any((session) => session.id == activeSessionId)
        ? activeSessionId
        : nextSessions.first.id;
    await _preferences.setString(
      _sessionsKey,
      ChatSession.encodeList(nextSessions),
    );
    await _preferences.setString(_activeSessionKey, nextActiveId);
  }
}

class SessionState {
  const SessionState({required this.sessions, required this.activeSessionId});

  final List<ChatSession> sessions;
  final String activeSessionId;
}
