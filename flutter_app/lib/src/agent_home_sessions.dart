part of 'agent_home_page.dart';

mixin _AgentHomeSessions on State<AgentHomePage> {
  SessionStore get _sessionStore;
  ScrollController get _messageScrollController;
  List<ChatSession> get _sessions;
  set _sessions(List<ChatSession> value);
  String? get _activeSessionId;
  set _activeSessionId(String? value);
  set _selectedView(AppView value);

  Future<void> _loadSessions() async {
    final state = await _sessionStore.load();
    if (!mounted) return;
    setState(() {
      _sessions = state.sessions;
      _activeSessionId = state.activeSessionId;
    });
    scrollChatToBottom(_messageScrollController);
  }

  void _persistSessions() {
    final activeSessionId = _activeSessionId;
    if (activeSessionId == null || _sessions.isEmpty) return;
    unawaited(
      _sessionStore.save(sessions: _sessions, activeSessionId: activeSessionId),
    );
  }

  void _createSession() {
    final activeSession = activeSessionFrom(_sessions, _activeSessionId);
    final hasTurns = activeSession.hasTurns;
    final session = hasTurns ? ChatSession.fresh() : activeSession;
    setState(() {
      if (hasTurns) _sessions = <ChatSession>[session, ..._sessions];
      _activeSessionId = session.id;
      _selectedView = AppView.chat;
    });
    if (!hasTurns) scrollChatToBottom(_messageScrollController);
  }

  void _selectSession(String sessionId) {
    setState(() {
      _activeSessionId = sessionId;
      _selectedView = AppView.chat;
    });
    scrollChatToBottom(_messageScrollController);
    _persistSessions();
  }

  void _deleteSession(String sessionId) {
    _applySessionMutation(
      deleteSessionFromSessions(
        sessions: _sessions,
        activeSessionId: _activeSessionId,
        sessionId: sessionId,
      ),
      selectChat: true,
    );
  }

  void _addToolTrace(ToolTrace trace) {
    _applySessionMutation(
      upsertToolTraceInSessions(
        sessions: _sessions,
        activeSessionId: _activeSessionId,
        message: ChatMessage.toolTrace(
          toolName: trace.toolName,
          status: trace.status,
          summary: trace.summary,
          callId: trace.callId,
        ),
      ),
    );
  }

  void _appendMessage(ChatMessage message) {
    _applySessionMutation(
      appendMessageToSessions(
        sessions: _sessions,
        activeSessionId: _activeSessionId,
        message: message,
      ),
    );
  }

  void _applySessionMutation(
    SessionMutation mutation, {
    bool selectChat = false,
  }) {
    if (!mounted) return;
    setState(() {
      _sessions = mutation.sessions;
      _activeSessionId = mutation.activeSessionId;
      if (selectChat) _selectedView = AppView.chat;
    });
    _persistSessions();
    scrollChatToBottom(_messageScrollController);
  }
}
