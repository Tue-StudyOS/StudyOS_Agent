import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'agent_config_store.dart';
import 'agent_message_sender.dart';
import 'chat_scroll.dart';
import 'chat_session_mutation.dart';
import 'mail_repository.dart';
import 'mail_tools.dart';
import 'memory_store.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'profile_context.dart';
import 'send_error_message.dart';
import 'session_store.dart';
import 'timetable_repository.dart';
import 'widgets/agent_home_scaffold.dart';

part 'agent_home_sessions.dart';
part 'agent_home_timetable.dart';

class AgentHomePage extends StatefulWidget {
  const AgentHomePage({
    this.profile,
    this.onLogout,
    this.onSaveProfile,
    super.key,
  });

  final OnboardingProfile? profile;
  final VoidCallback? onLogout;
  final Future<void> Function(OnboardingProfile profile)? onSaveProfile;

  @override
  State<AgentHomePage> createState() => _AgentHomePageState();
}

class _AgentHomePageState extends State<AgentHomePage>
    with _AgentHomeSessions, _AgentHomeTimetable {
  @override
  final NativeBridge _bridge = NativeBridge();
  @override
  final SessionStore _sessionStore = SessionStore();
  final AgentConfigStore _configStore = AgentConfigStore();
  final MailRepository _mailRepository = MailRepository();
  final MemoryStore _memoryStore = MemoryStore();
  @override
  final TimetableRepository _timetableRepository = TimetableRepository();
  final TextEditingController _inputController = TextEditingController();
  @override
  final ScrollController _messageScrollController = ScrollController();

  StreamSubscription<NativeEvent>? _eventSubscription;
  @override
  List<ChatSession> _sessions = <ChatSession>[];
  @override
  String? _activeSessionId;
  AgentConfig _agentConfig = const AgentConfig.defaults();
  String _memoryText = '';
  @override
  TimetableSnapshot? _timetable;
  @override
  String? _timetableError;
  @override
  Map<String, Object?> _worldState = const {};
  @override
  AppView _selectedView = AppView.home;
  String _status = 'Starting';
  bool _isSending = false;
  bool _compactMessages = false;
  @override
  bool _isRefreshingTimetable = false;

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
    unawaited(_loadTimetable());
    unawaited(_initializeNativeLayer());
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _inputController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AgentHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile == widget.profile) return;
    setState(
      () => _worldState = withProfileContext(
        _worldState,
        widget.profile,
        timetable: _timetable,
      ),
    );
  }

  Future<void> _initializeNativeLayer() async {
    try {
      final init = await _bridge.initialize();
      final worldState = await _bridge.getWorldState();
      if (!mounted) return;

      setState(() {
        _status = init['status']?.toString() ?? 'Ready';
        _worldState = withProfileContext(
          worldState,
          widget.profile,
          timetable: _timetable,
        );
      });
      await _publishIntentSnapshot();
      await _loadPendingIntentPrompt();
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

  Future<void> _loadAgentConfig() async {
    final config = await _configStore.load();
    if (!mounted) return;
    setState(() => _agentConfig = config);
  }

  Future<void> _loadMemory() async {
    final memory = await _memoryStore.read();
    if (!mounted) return;
    setState(() => _memoryText = memory);
    unawaited(_publishIntentSnapshot());
  }

  Future<void> _appendMemory(String text) async {
    await _memoryStore.append(text);
    await _loadMemory();
  }

  Future<void> _saveMemory(String text) async {
    await _memoryStore.writeDocument(text);
    await _loadMemory();
  }

  @override
  Future<void> _publishIntentSnapshot() async {
    try {
      await _bridge.publishIntentSnapshot(
        timetable: _timetable,
        memoryText: _memoryText,
      );
    } on MissingPluginException {
      // Non-iOS platforms do not expose App Intents.
    } on PlatformException catch (error) {
      debugPrint('Intent snapshot publish failed: ${error.message}');
    }
  }

  Future<void> _loadPendingIntentPrompt() async {
    try {
      final prompt = await _bridge.consumePendingIntentPrompt();
      final text = prompt?.trim();
      if (!mounted || text == null || text.isEmpty) return;
      setState(() {
        _inputController.text = text;
        _inputController.selection = TextSelection.collapsed(
          offset: text.length,
        );
        _selectedView = AppView.chat;
      });
    } on MissingPluginException {
      // Non-iOS platforms do not expose App Intents.
    } on PlatformException catch (error) {
      debugPrint('Pending intent prompt read failed: ${error.message}');
    }
  }

  Future<void> _saveAgentConfig(AgentConfig config, String? apiKey) async {
    await _configStore.save(config: config, apiKey: apiKey);
    final savedConfig = await _configStore.load();
    if (!mounted) return;
    setState(() => _agentConfig = savedConfig);
  }

  void _useSuggestion(String text) {
    _inputController.text = text;
    _inputController.selection = TextSelection.collapsed(offset: text.length);
  }

  void _prefillChatPrompt(String text) {
    setState(() {
      _inputController.text = text;
      _inputController.selection = TextSelection.collapsed(offset: text.length);
      _selectedView = AppView.chat;
    });
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
        timetable: _timetable,
        worldState: _worldState,
        userText: text,
        appendMemory: _appendMemory,
        readSchedule: _readScheduleForAgent,
        mailTools: MailToolRunner(
          repository: _mailRepository,
          profile: widget.profile,
        ),
        onToolTrace: _addToolTrace,
      );
      _addAssistantMessage(response);
      await _loadMemory();
      final worldState = await _bridge.getWorldState();
      if (!mounted) return;
      setState(
        () => _worldState = withProfileContext(
          worldState,
          widget.profile,
          timetable: _timetable,
        ),
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
      timetable: _timetable,
      timetableError: _timetableError,
      isRefreshingTimetable: _isRefreshingTimetable,
      agentConfig: _agentConfig,
      nativeBridge: _bridge,
      profile: widget.profile,
      onSelectView: (view) => setState(() => _selectedView = view),
      onSelectSession: _selectSession,
      onCreateSession: _createSession,
      onDeleteSession: _deleteSession,
      onSuggestionSelected: _useSuggestion,
      onSend: _sendMessage,
      onAskAssistant: _prefillChatPrompt,
      onLogout: widget.onLogout,
      onSaveProfile: widget.onSaveProfile,
      onSaveAgentConfig: _saveAgentConfig,
      onSaveMemory: _saveMemory,
      onRefreshTimetable: _refreshTimetable,
      onCompactMessagesChanged: (value) =>
          setState(() => _compactMessages = value),
    );
  }
}
