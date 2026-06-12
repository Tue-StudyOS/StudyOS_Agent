import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'agent_config_store.dart';
import 'agent_message_sender.dart';
import 'chat_scroll.dart';
import 'chat_session_mutation.dart';
import 'memory_store.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'profile_context.dart';
import 'send_error_message.dart';
import 'session_store.dart';
import 'widgets/agent_home_scaffold.dart';

class AgentHomePage extends StatefulWidget {
  const AgentHomePage({this.profile, this.onLogout, super.key});

  final OnboardingProfile? profile;
  final VoidCallback? onLogout;

  @override
  State<AgentHomePage> createState() => _AgentHomePageState();
}

class _AgentHomePageState extends State<AgentHomePage> {
  final NativeBridge _bridge = NativeBridge();
  final SessionStore _sessionStore = SessionStore();
  final AgentConfigStore _configStore = AgentConfigStore();
  final MemoryStore _memoryStore = MemoryStore();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();

  StreamSubscription<NativeEvent>? _eventSubscription;
  List<ChatSession> _sessions = <ChatSession>[];
  String? _activeSessionId;
  AgentConfig _agentConfig = const AgentConfig.defaults();
  String _memoryText = '';
  Map<String, Object?> _worldState = const {};
  AppView _selectedView = AppView.home;
  String _status = 'Starting';
  bool _isSending = false;
  bool _compactMessages = false;

  @override
  void initState() {
    super.initState();
    _eventSubscription = _bridge.events.listen(
      _handleNativeEvent,
      onError: (Object error) {
        if (mounted) setState(() => _status = 'Native events unavailable');
      },
    );
    unawaited(_loadSessions());
    unawaited(_loadAgentConfig());
    unawaited(_loadMemory());
    unawaited(_initializeNativeLayer());
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _inputController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeNativeLayer() async {
    try {
      final init = await _bridge.initialize();
      final worldState = await _bridge.getWorldState();
      if (!mounted) return;

      setState(() {
        _status = init['status']?.toString() ?? 'Ready';
        _worldState = withProfileContext(worldState, widget.profile);
      });
    } on MissingPluginException {
      setState(() => _status = 'Bridge missing');
    } on PlatformException catch (error) {
      debugPrint('Native bridge failed: ${error.message}');
      setState(() => _status = 'Bridge failed');
    }
  }

  void _handleNativeEvent(NativeEvent event) {
    if (!mounted) return;
    final trace = event.trace;
    if (event.type == 'toolTrace' && trace != null) {
      _addToolTrace(trace);
      return;
    }
    if (event.message.isEmpty) return;
    setState(() => _status = event.message);
  }

  Future<void> _loadSessions() async {
    final state = await _sessionStore.load();
    if (!mounted) return;
    setState(() {
      _sessions = state.sessions;
      _activeSessionId = state.activeSessionId;
    });
    scrollChatToBottom(_messageScrollController);
  }

  Future<void> _loadAgentConfig() async {
    final config = await _configStore.load();
    if (!mounted) return;
    setState(() => _agentConfig = config);
  }

  Future<void> _loadMemory() async {
    final memory = await _memoryStore.read();
    if (!mounted) return;
    setState(() => _memoryText = memory);
  }

  Future<void> _appendMemory(String text) async {
    await _memoryStore.append(text);
    await _loadMemory();
  }

  Future<void> _saveMemory(String text) async {
    await _memoryStore.writeDocument(text);
    await _loadMemory();
  }

  Future<void> _saveAgentConfig(AgentConfig config, String? apiKey) async {
    await _configStore.save(config: config, apiKey: apiKey);
    final savedConfig = await _configStore.load();
    if (!mounted) return;
    setState(() => _agentConfig = savedConfig);
  }

  void _persistSessions() {
    final activeSessionId = _activeSessionId;
    if (activeSessionId == null || _sessions.isEmpty) return;
    unawaited(
      _sessionStore.save(sessions: _sessions, activeSessionId: activeSessionId),
    );
  }

  void _useSuggestion(String text) {
    _inputController.text = text;
    _inputController.selection = TextSelection.collapsed(offset: text.length);
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

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _inputController.clear();
    });
    _appendMessage(ChatMessage(author: 'You', text: text, isUser: true));

    try {
      final response = await sendAgentMessage(
        config: _agentConfig,
        bridge: _bridge,
        configStore: _configStore,
        memoryStore: _memoryStore,
        profile: widget.profile,
        sessions: _sessions,
        activeSessionId: _activeSessionId,
        memoryText: _memoryText,
        worldState: _worldState,
        userText: text,
        appendMemory: _appendMemory,
        onToolTrace: _addToolTrace,
      );
      _addAssistantMessage(response);
      await _loadMemory();
      final worldState = await _bridge.getWorldState();
      if (!mounted) return;
      setState(
        () => _worldState = withProfileContext(worldState, widget.profile),
      );
    } on Object catch (error) {
      final message = sendErrorMessage(error);
      if (message == null) rethrow;
      _addAssistantMessage(message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _addAssistantMessage(String text) {
    if (!mounted) return;
    _appendMessage(
      ChatMessage(author: 'StudyOS Agent', text: text, isUser: false),
    );
    setState(() => _status = text);
    unawaited(HapticFeedback.lightImpact());
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

  @override
  Widget build(BuildContext context) {
    return AgentHomeScaffold(
      selectedView: _selectedView,
      sessions: _sessions,
      activeSessionId: _activeSessionId,
      inputController: _inputController,
      messageScrollController: _messageScrollController,
      isSending: _isSending,
      compactMessages: _compactMessages,
      status: _status,
      worldState: _worldState,
      memoryText: _memoryText,
      agentConfig: _agentConfig,
      profile: widget.profile,
      onSelectView: (view) => setState(() => _selectedView = view),
      onSelectSession: _selectSession,
      onCreateSession: _createSession,
      onDeleteSession: _deleteSession,
      onSuggestionSelected: _useSuggestion,
      onSend: _sendMessage,
      onLogout: widget.onLogout,
      onSaveAgentConfig: _saveAgentConfig,
      onSaveMemory: _saveMemory,
      onCompactMessagesChanged: (value) =>
          setState(() => _compactMessages = value),
    );
  }
}
