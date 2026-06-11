import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'agent_config_store.dart';
import 'cloud_agent_client.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'session_store.dart';
import 'studyos_theme.dart';
import 'views/chat_view.dart';
import 'views/memories_view.dart';
import 'views/settings_view.dart';
import 'widgets/app_drawer.dart';
import 'widgets/study_header.dart';

class AgentHomePage extends StatefulWidget {
  const AgentHomePage({super.key});

  @override
  State<AgentHomePage> createState() => _AgentHomePageState();
}

class _AgentHomePageState extends State<AgentHomePage> {
  final NativeBridge _bridge = NativeBridge();
  final SessionStore _sessionStore = SessionStore();
  final AgentConfigStore _configStore = AgentConfigStore();
  final CloudAgentClient _cloudClient = CloudAgentClient();
  final TextEditingController _inputController = TextEditingController();

  StreamSubscription<NativeEvent>? _eventSubscription;
  List<ChatSession> _sessions = <ChatSession>[];
  String? _activeSessionId;
  AgentConfig _agentConfig = const AgentConfig.defaults();
  Map<String, Object?> _worldState = const {};
  AppView _selectedView = AppView.chat;
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
    unawaited(_initializeNativeLayer());
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _initializeNativeLayer() async {
    try {
      final init = await _bridge.initialize();
      final worldState = await _bridge.getWorldState();
      if (!mounted) return;

      setState(() {
        _status = init['status']?.toString() ?? 'Ready';
        _worldState = worldState;
      });
    } on MissingPluginException {
      setState(() => _status = 'Bridge missing');
    } on PlatformException catch (error) {
      debugPrint('Native bridge failed: ${error.message}');
      setState(() => _status = 'Bridge failed');
    }
  }

  void _handleNativeEvent(NativeEvent event) {
    if (!mounted || event.message.isEmpty) return;
    setState(() => _status = event.message);
  }

  ChatSession? get _activeSession {
    for (final session in _sessions) {
      if (session.id == _activeSessionId) return session;
    }
    return _sessions.isEmpty ? null : _sessions.first;
  }

  Future<void> _loadSessions() async {
    final state = await _sessionStore.load();
    if (!mounted) return;
    setState(() {
      _sessions = state.sessions;
      _activeSessionId = state.activeSessionId;
    });
  }

  Future<void> _loadAgentConfig() async {
    final config = await _configStore.load();
    if (!mounted) return;
    setState(() => _agentConfig = config);
  }

  Future<void> _saveAgentConfig(AgentConfig config, String? apiKey) async {
    await _configStore.save(config: config, apiKey: apiKey);
    final savedConfig = await _configStore.load();
    if (!mounted) return;
    setState(() => _agentConfig = savedConfig);
  }

  Future<void> _persistSessions() async {
    final activeSessionId = _activeSessionId;
    if (activeSessionId == null || _sessions.isEmpty) return;
    await _sessionStore.save(
      sessions: _sessions,
      activeSessionId: activeSessionId,
    );
  }

  void _useSuggestion(String text) {
    _inputController.text = text;
    _inputController.selection = TextSelection.collapsed(offset: text.length);
  }

  void _createSession() {
    final session = ChatSession.fresh();
    setState(() {
      _sessions = <ChatSession>[session, ..._sessions];
      _activeSessionId = session.id;
      _selectedView = AppView.chat;
    });
    unawaited(_persistSessions());
  }

  void _selectSession(String sessionId) {
    setState(() {
      _activeSessionId = sessionId;
      _selectedView = AppView.chat;
    });
    unawaited(_persistSessions());
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _inputController.clear();
      _appendMessage(ChatMessage(author: 'You', text: text, isUser: true));
    });

    try {
      final response = await _sendToSelectedProvider(text);
      _addAssistantMessage(response);
      final worldState = await _bridge.getWorldState();
      if (!mounted) return;
      setState(() => _worldState = worldState);
    } on CloudAgentException catch (error) {
      _addAssistantMessage(error.message);
    } on MissingPluginException {
      _addAssistantMessage('Native bridge is not implemented on this target.');
    } on PlatformException catch (error) {
      _addAssistantMessage('Native bridge error: ${error.message}');
    } on FormatException {
      _addAssistantMessage('Cloud response could not be read.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<String> _sendToSelectedProvider(String text) async {
    if (!_agentConfig.usesCloud) {
      return _bridge.sendMessage(text);
    }

    final apiKey = await _configStore.readApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const CloudAgentException('Cloud API key is required.');
    }
    return _cloudClient.sendMessage(
      config: _agentConfig,
      apiKey: apiKey,
      history: _activeSession?.messages ?? const <ChatMessage>[],
      userText: text,
    );
  }

  void _addAssistantMessage(String text) {
    if (!mounted) return;
    setState(() {
      _appendMessage(
        ChatMessage(author: 'StudyOS Agent', text: text, isUser: false),
      );
      _status = text;
    });
  }

  void _appendMessage(ChatMessage message) {
    final activeSession = _activeSession ?? ChatSession.fresh();
    final nextMessages = <ChatMessage>[...activeSession.messages, message];
    final nextSession = activeSession.copyWith(
      title: _titleForMessages(nextMessages),
      updatedAt: DateTime.now(),
      messages: nextMessages,
    );
    final existing = _sessions.any((session) => session.id == activeSession.id);

    _sessions = existing
        ? _sessions
              .map(
                (session) =>
                    session.id == activeSession.id ? nextSession : session,
              )
              .toList()
        : <ChatSession>[nextSession, ..._sessions];
    _activeSessionId = nextSession.id;
    unawaited(_persistSessions());
  }

  String _titleForMessages(List<ChatMessage> messages) {
    ChatMessage? firstUserMessage;
    for (final message in messages) {
      if (message.isUser) {
        firstUserMessage = message;
        break;
      }
    }
    final text = firstUserMessage?.text.trim();
    if (text == null || text.isEmpty) return 'New chat';
    return text.length > 34 ? '${text.substring(0, 34)}…' : text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        selectedView: _selectedView,
        sessions: _sessions,
        activeSessionId: _activeSessionId,
        onSelectView: (view) => setState(() => _selectedView = view),
        onSelectSession: _selectSession,
        onCreateSession: _createSession,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: StudyOsSpacing.lg,
              ),
              child: Column(
                children: <Widget>[
                  StudyHeader(status: _status),
                  Expanded(child: _buildSelectedView()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedView() {
    return switch (_selectedView) {
      AppView.chat => ChatView(
        messages: _activeSession?.messages ?? const <ChatMessage>[],
        inputController: _inputController,
        isSending: _isSending,
        compactMessages: _compactMessages,
        onSuggestionSelected: _useSuggestion,
        onSend: _sendMessage,
      ),
      AppView.memories => MemoriesView(worldState: _worldState),
      AppView.settings => SettingsView(
        config: _agentConfig,
        status: _status,
        compactMessages: _compactMessages,
        onSaveAgentConfig: _saveAgentConfig,
        onCompactMessagesChanged: (value) {
          setState(() => _compactMessages = value);
        },
      ),
    };
  }
}
