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
  final existing = sessions.any((session) => session.id == activeSession.id);

  return SessionMutation(
    sessions: existing
        ? sessions
              .map(
                (session) =>
                    session.id == activeSession.id ? nextSession : session,
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
    if (!message.isUser) continue;
    final text = message.text.trim();
    if (text.isEmpty) break;
    return text.length > 34 ? '${text.substring(0, 34)}…' : text;
  }
  return 'New chat';
}
