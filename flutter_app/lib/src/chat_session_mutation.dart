import 'models.dart';

class SessionMutation {
  const SessionMutation({
    required this.sessions,
    required this.activeSessionId,
  });

  final List<ChatSession> sessions;
  final String activeSessionId;
}

SessionMutation appendMessageToSessions({
  required List<ChatSession> sessions,
  required String? activeSessionId,
  required ChatMessage message,
}) {
  final activeSession = activeSessionFrom(sessions, activeSessionId);
  final nextMessages = <ChatMessage>[...activeSession.messages, message];
  final nextSession = activeSession.copyWith(
    title: _titleForMessages(nextMessages),
    updatedAt: DateTime.now(),
    messages: nextMessages,
  );

  return _replaceSession(sessions, activeSession.id, nextSession);
}

SessionMutation upsertToolTraceInSessions({
  required List<ChatSession> sessions,
  required String? activeSessionId,
  required ChatMessage message,
}) {
  final callId = message.trace?.callId;
  if (callId == null || callId.isEmpty) {
    return appendMessageToSessions(
      sessions: sessions,
      activeSessionId: activeSessionId,
      message: message,
    );
  }

  final activeSession = activeSessionFrom(sessions, activeSessionId);
  var replaced = false;
  final nextMessages = activeSession.messages.map((item) {
    if (item.trace?.callId != callId) return item;
    replaced = true;
    return message;
  }).toList();
  if (!replaced) {
    return appendMessageToSessions(
      sessions: sessions,
      activeSessionId: activeSessionId,
      message: message,
    );
  }

  final nextSession = activeSession.copyWith(
    updatedAt: DateTime.now(),
    messages: nextMessages,
  );
  return _replaceSession(sessions, activeSession.id, nextSession);
}

SessionMutation _replaceSession(
  List<ChatSession> sessions,
  String activeSessionId,
  ChatSession nextSession,
) {
  final existing = sessions.any((session) => session.id == activeSessionId);
  return SessionMutation(
    sessions: existing
        ? sessions
              .map(
                (session) =>
                    session.id == activeSessionId ? nextSession : session,
              )
              .toList()
        : <ChatSession>[nextSession, ...sessions],
    activeSessionId: nextSession.id,
  );
}

ChatSession activeSessionFrom(
  List<ChatSession> sessions,
  String? activeSessionId,
) {
  for (final session in sessions) {
    if (session.id == activeSessionId) return session;
  }
  return sessions.isEmpty ? ChatSession.fresh() : sessions.first;
}

String _titleForMessages(List<ChatMessage> messages) {
  for (final message in messages) {
    if (!message.isUser || message.isTrace) continue;
    final text = message.text.trim();
    if (text.isEmpty) break;
    return text.length > 34 ? '${text.substring(0, 34)}…' : text;
  }
  return 'New chat';
}
