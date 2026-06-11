import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'agent_config_store.dart';
import 'chat_session_mutation.dart';
import 'cloud_agent_client.dart';
import 'memory_store.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'profile_context.dart';
import 'prompt_context.dart';
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
  final CloudAgentClient _cloudClient = CloudAgentClient();
  final TextEditingController _inputController = TextEditingController();

  StreamSubscription<NativeEvent>? _eventSubscription;
  List<ChatSession> _sessions = <ChatSession>[];
  String? _activeSessionId;
  AgentConfig _agentConfig = const AgentConfig.defaults();
  String _memoryText = '';
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
    unawaited(_loadMemory());
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
    if (!mounted || event.message.isEmpty) return;
    setState(() => _status = event.message);
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

  Future<void> _loadMemory() async {
    final memory = await _memoryStore.read();
    if (!mounted) return;
    setState(() => _memoryText = memory);
  }

  Future<void> _appendMemory(String text) async {
    await _memoryStore.append(text);
    final memory = await _memoryStore.read();
    if (!mounted) return;
    setState(() => _memoryText = memory);
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
      setState(
        () => _worldState = withProfileContext(worldState, widget.profile),
      );
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
    final context = PromptContext(
      profile: widget.profile,
      memory: _memoryText,
      worldState: _worldState,
    );
    _addToolTrace(
      ToolTrace(
        toolName: 'get_study_context',
        status: 'attached',
        summary: _contextTraceSummary(),
      ),
    );
    if (!_agentConfig.usesCloud) {
      return _bridge.sendMessage(text, systemPrompt: context.systemPrompt());
    }

    final apiKey = await _configStore.readApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const CloudAgentException('Cloud API key is required.');
    }
    return _cloudClient.sendMessage(
      config: _agentConfig,
      apiKey: apiKey,
      history: activeSessionFrom(_sessions, _activeSessionId).messages,
      userText: text,
      context: context,
      appendMemory: _appendMemory,
      readMemory: _memoryStore.read,
      onToolTrace: _addToolTrace,
    );
  }

  String _contextTraceSummary() {
    final parts = <String>[
      if (widget.profile != null) 'profile',
      if (_memoryText.trim().isNotEmpty) 'memory',
      if (_worldState.isNotEmpty) 'device state',
    ];
    if (parts.isEmpty) return 'No local context available yet.';
    return 'Attached ${parts.join(', ')} to the model request.';
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

  void _addToolTrace(ToolTrace trace) {
    if (!mounted) return;
    setState(() {
      _appendMessage(
        ChatMessage.toolTrace(
          toolName: trace.toolName,
          status: trace.status,
          summary: trace.summary,
        ),
      );
    });
  }

  void _appendMessage(ChatMessage message) {
    final mutation = appendMessageToSessions(
      sessions: _sessions,
      activeSessionId: _activeSessionId,
      message: message,
    );
    _sessions = mutation.sessions;
    _activeSessionId = mutation.activeSessionId;
    unawaited(_persistSessions());
  }

  @override
  Widget build(BuildContext context) {
    return AgentHomeScaffold(
      selectedView: _selectedView,
      sessions: _sessions,
      activeSessionId: _activeSessionId,
      inputController: _inputController,
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
      onSuggestionSelected: _useSuggestion,
      onSend: _sendMessage,
      onLogout: widget.onLogout,
      onSaveAgentConfig: _saveAgentConfig,
      onCompactMessagesChanged: (value) {
        setState(() => _compactMessages = value);
      },
    );
  }
}
