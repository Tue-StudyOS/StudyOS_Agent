import 'dart:async';

import 'package:flutter/foundation.dart';
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

class ChatRouteRequest {
  const ChatRouteRequest({this.prompt, this.autosend = false, this.sessionId});

  final String? prompt;
  final bool autosend;
  final String? sessionId;

  Uri toUri() {
    final query = <String, String>{
      if (prompt?.trim().isNotEmpty == true) 'prompt': prompt!.trim(),
      if (autosend) 'autosend': 'true',
      if (sessionId?.trim().isNotEmpty == true) 'sessionId': sessionId!.trim(),
    };
    return Uri(path: '/chat', queryParameters: query.isEmpty ? null : query);
  }
}

class AppShellController extends ChangeNotifier {
  AppShellController({
    required OnboardingProfile? profile,
    required VoidCallback? onLogout,
    required Future<void> Function(OnboardingProfile profile)? onSaveProfile,
    this.onOpenChatRequest,
  }) : _profile = profile,
       _onLogout = onLogout,
       _onSaveProfile = onSaveProfile;

  final NativeBridge bridge = NativeBridge();
  final SessionStore _sessionStore = SessionStore();
  final AgentConfigStore _configStore = AgentConfigStore();
  final MailRepository _mailRepository = MailRepository();
  final MemoryStore _memoryStore = MemoryStore();
  final TimetableRepository _timetableRepository = TimetableRepository();
  final TextEditingController inputController = TextEditingController();
  final ScrollController messageScrollController = ScrollController();

  ValueChanged<ChatRouteRequest>? onOpenChatRequest;
  StreamSubscription<NativeEvent>? _eventSubscription;
  bool _disposed = false;

  OnboardingProfile? _profile;
  VoidCallback? _onLogout;
  Future<void> Function(OnboardingProfile profile)? _onSaveProfile;
  List<ChatSession> _sessions = <ChatSession>[];
  String? _activeSessionId;
  AgentConfig _agentConfig = const AgentConfig.defaults();
  String _memoryText = '';
  TimetableSnapshot? _timetable;
  String? _timetableError;
  Map<String, Object?> _worldState = const {};
  String _status = 'Starting';
  bool _isSending = false;
  bool _compactMessages = false;
  bool _isRefreshingTimetable = false;

  OnboardingProfile? get profile => _profile;
  VoidCallback? get onLogout => _onLogout;
  List<ChatSession> get sessions => _sessions;
  String? get activeSessionId => _activeSessionId;
  AgentConfig get agentConfig => _agentConfig;
  String get memoryText => _memoryText;
  TimetableSnapshot? get timetable => _timetable;
  String? get timetableError => _timetableError;
  Map<String, Object?> get worldState => _worldState;
  String get status => _status;
  bool get isSending => _isSending;
  bool get compactMessages => _compactMessages;
  bool get isRefreshingTimetable => _isRefreshingTimetable;

  ChatSession get activeSession =>
      activeSessionFrom(_sessions, _activeSessionId);

  Future<void> initialize() async {
    _eventSubscription = bridge.events.listen(
      _handleNativeEvent,
      onError: (_) => _setStatus('Native events unavailable'),
    );
    unawaited(loadSessions());
    unawaited(_loadAgentConfig());
    unawaited(_loadMemory());
    unawaited(_loadTimetable());
    unawaited(_initializeNativeLayer());
  }

  void updateProfile({
    required OnboardingProfile? profile,
    required VoidCallback? onLogout,
    required Future<void> Function(OnboardingProfile profile)? onSaveProfile,
  }) {
    if (_profile == profile &&
        _onLogout == onLogout &&
        _onSaveProfile == onSaveProfile) {
      return;
    }
    _profile = profile;
    _onLogout = onLogout;
    _onSaveProfile = onSaveProfile;
    _worldState = withProfileContext(
      _worldState,
      _profile,
      timetable: _timetable,
    );
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _eventSubscription?.cancel();
    inputController.dispose();
    messageScrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeNativeLayer() async {
    try {
      final init = await bridge.initialize();
      final worldState = await bridge.getWorldState();
      if (_disposed) return;
      _status = init['status']?.toString() ?? 'Ready';
      _worldState = withProfileContext(
        worldState,
        _profile,
        timetable: _timetable,
      );
      _notify();
      await publishIntentSnapshot();
      await consumePendingIntentPrompt();
    } on MissingPluginException {
      _setStatus('Bridge missing');
    } on PlatformException catch (error) {
      debugPrint('Native bridge failed: ${error.message}');
      _setStatus('Bridge failed');
    }
  }

  void _handleNativeEvent(NativeEvent event) {
    if (_disposed) return;
    final trace = event.trace;
    if (event.type == 'toolTrace' && trace != null) {
      addToolTrace(trace);
      return;
    }
    if (event.type == 'voicePrompt' && event.message.trim().isNotEmpty) {
      onOpenChatRequest?.call(
        ChatRouteRequest(prompt: event.message, autosend: true),
      );
      return;
    }
    if (event.message.isEmpty) return;
    _setStatus(event.message);
  }

  Future<void> _loadAgentConfig() async {
    final config = await _configStore.load();
    if (_disposed) return;
    _agentConfig = config;
    _notify();
  }

  Future<void> _loadMemory() async {
    final memory = await _memoryStore.read();
    if (_disposed) return;
    _memoryText = memory;
    _notify();
    unawaited(publishIntentSnapshot());
  }

  Future<void> appendMemory(String text) async {
    await _memoryStore.append(text);
    await _loadMemory();
  }

  Future<void> saveMemory(String text) async {
    await _memoryStore.writeDocument(text);
    await _loadMemory();
  }

  Future<void> saveAgentConfig(AgentConfig config, String? apiKey) async {
    await _configStore.save(config: config, apiKey: apiKey);
    final savedConfig = await _configStore.load();
    if (_disposed) return;
    _agentConfig = savedConfig;
    _notify();
  }

  Future<void> saveProfile(OnboardingProfile profile) async {
    await (_onSaveProfile ?? (_) async {})(profile);
    if (_disposed) return;
    _profile = profile;
    _worldState = withProfileContext(
      _worldState,
      _profile,
      timetable: _timetable,
    );
    _notify();
  }

  void setCompactMessages(bool value) {
    if (_compactMessages == value) return;
    _compactMessages = value;
    _notify();
  }

  void useSuggestion(String text) {
    inputController.text = text;
    inputController.selection = TextSelection.collapsed(offset: text.length);
  }

  void prefillChatPrompt(String text) {
    onOpenChatRequest?.call(ChatRouteRequest(prompt: text));
  }

  Future<void> applyChatRoute({
    String? prompt,
    bool autosend = false,
    String? sessionId,
  }) async {
    final targetSession = sessionId?.trim();
    if (targetSession != null &&
        targetSession.isNotEmpty &&
        _sessions.any((session) => session.id == targetSession)) {
      _activeSessionId = targetSession;
      _persistSessions();
    }
    final trimmedPrompt = prompt?.trim();
    if (trimmedPrompt != null && trimmedPrompt.isNotEmpty) {
      inputController.text = trimmedPrompt;
      inputController.selection = TextSelection.collapsed(
        offset: trimmedPrompt.length,
      );
    }
    _notify();
    scrollChatToBottom(messageScrollController);
    if (autosend && trimmedPrompt != null && trimmedPrompt.isNotEmpty) {
      await sendMessage();
    }
  }

  Future<void> sendMessage() async {
    final text = inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    _isSending = true;
    inputController.clear();
    _notify();
    appendMessage(ChatMessage(author: 'You', text: text, isUser: true));

    try {
      final response = await sendAgentMessage(
        config: _agentConfig,
        bridge: bridge,
        configStore: _configStore,
        memoryStore: _memoryStore,
        profile: _profile,
        sessions: _sessions,
        activeSessionId: _activeSessionId,
        memoryText: _memoryText,
        timetable: _timetable,
        worldState: _worldState,
        userText: text,
        appendMemory: appendMemory,
        readSchedule: readScheduleForAgent,
        mailTools: MailToolRunner(
          repository: _mailRepository,
          profile: _profile,
        ),
        onToolTrace: addToolTrace,
      );
      addAssistantMessage(response);
      await _loadMemory();
      final worldState = await bridge.getWorldState();
      if (_disposed) return;
      _worldState = withProfileContext(
        worldState,
        _profile,
        timetable: _timetable,
      );
      _notify();
    } on Object catch (error) {
      final message = sendErrorMessage(error);
      if (message == null) rethrow;
      addAssistantMessage(message);
    } finally {
      if (!_disposed) {
        _isSending = false;
        _notify();
      }
    }
  }

  void addAssistantMessage(String text) {
    if (_disposed) return;
    appendMessage(
      ChatMessage(author: 'StudyOS Agent', text: text, isUser: false),
    );
    _status = text;
    _notify();
    unawaited(HapticFeedback.lightImpact());
  }

  Future<void> loadSessions() async {
    final state = await _sessionStore.load();
    if (_disposed) return;
    _sessions = state.sessions;
    _activeSessionId = state.activeSessionId;
    _notify();
    scrollChatToBottom(messageScrollController);
  }

  void createSession() {
    final activeSession = activeSessionFrom(_sessions, _activeSessionId);
    final hasTurns = activeSession.hasTurns;
    final session = hasTurns ? ChatSession.fresh() : activeSession;
    if (hasTurns) _sessions = <ChatSession>[session, ..._sessions];
    _activeSessionId = session.id;
    _notify();
    if (!hasTurns) scrollChatToBottom(messageScrollController);
    _persistSessions();
    onOpenChatRequest?.call(ChatRouteRequest(sessionId: session.id));
  }

  void selectSession(String sessionId) {
    _activeSessionId = sessionId;
    _notify();
    scrollChatToBottom(messageScrollController);
    _persistSessions();
    onOpenChatRequest?.call(ChatRouteRequest(sessionId: sessionId));
  }

  void deleteSession(String sessionId) {
    _applySessionMutation(
      deleteSessionFromSessions(
        sessions: _sessions,
        activeSessionId: _activeSessionId,
        sessionId: sessionId,
      ),
    );
  }

  void addToolTrace(ToolTrace trace) {
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

  void appendMessage(ChatMessage message) {
    _applySessionMutation(
      appendMessageToSessions(
        sessions: _sessions,
        activeSessionId: _activeSessionId,
        message: message,
      ),
    );
  }

  void _applySessionMutation(SessionMutation mutation) {
    if (_disposed) return;
    _sessions = mutation.sessions;
    _activeSessionId = mutation.activeSessionId;
    _notify();
    _persistSessions();
    scrollChatToBottom(messageScrollController);
  }

  void _persistSessions() {
    final activeSessionId = _activeSessionId;
    if (activeSessionId == null || _sessions.isEmpty) return;
    unawaited(
      _sessionStore.save(sessions: _sessions, activeSessionId: activeSessionId),
    );
  }

  Future<void> _loadTimetable() async {
    final snapshot = await _timetableRepository.load();
    if (_disposed) return;
    _timetable = snapshot;
    _notify();
    unawaited(publishIntentSnapshot());
    if (snapshot == null || snapshot.isStale) {
      await refreshTimetable();
    }
  }

  Future<void> refreshTimetable() async {
    if (_isRefreshingTimetable) return;
    final profile = _profile;
    if (profile == null) {
      _timetableError = 'Sign in again to refresh your timetable.';
      _notify();
      return;
    }
    _isRefreshingTimetable = true;
    _timetableError = null;
    _notify();
    try {
      final snapshot = await _timetableRepository.refresh(profile);
      if (_disposed) return;
      final worldState = await bridge.getWorldState();
      if (_disposed) return;
      _timetable = snapshot;
      _worldState = withProfileContext(
        worldState,
        _profile,
        timetable: snapshot,
      );
      _notify();
      unawaited(publishIntentSnapshot());
    } on Object catch (error) {
      if (!_disposed) {
        _timetableError = error.toString();
        _notify();
      }
    } finally {
      if (!_disposed) {
        _isRefreshingTimetable = false;
        _notify();
      }
    }
  }

  Future<String> readScheduleForAgent() async {
    var snapshot = _timetable;
    if (snapshot == null || snapshot.isStale) {
      await refreshTimetable();
      snapshot = _timetable;
    }
    return snapshot?.compactSummary(limit: 12) ??
        'No timetable has been synced yet.';
  }

  Future<void> publishIntentSnapshot() async {
    try {
      await bridge.publishIntentSnapshot(
        timetable: _timetable,
        memoryText: _memoryText,
      );
    } on MissingPluginException {
      // Non-iOS platforms do not expose App Intents.
    } on PlatformException catch (error) {
      debugPrint('Intent snapshot publish failed: ${error.message}');
    }
  }

  Future<void> consumePendingIntentPrompt() async {
    try {
      final prompt = await bridge.consumePendingIntentPrompt();
      final text = prompt?.trim();
      if (_disposed || text == null || text.isEmpty) return;
      onOpenChatRequest?.call(ChatRouteRequest(prompt: text));
    } on MissingPluginException {
      // Non-iOS platforms do not expose App Intents.
    } on PlatformException catch (error) {
      debugPrint('Pending intent prompt read failed: ${error.message}');
    }
  }

  void _setStatus(String status) {
    if (_disposed) return;
    _status = status;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
