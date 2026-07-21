import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'agent_config_store.dart';
import 'agent_message_sender.dart';
import 'academic_repository.dart';
import 'calendar_overview_repository.dart';
import 'chat_scroll.dart';
import 'chat_session_mutation.dart';
import 'mail_repository.dart';
import 'mail_tools.dart';
import 'memory_store.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'official_document_models.dart';
import 'official_documents_repository.dart';
import 'profile_context.dart';
import 'alma_study_capability.dart';
import 'alma_study_tools.dart';
import 'private_study_capabilities.dart';
import 'private_study_tools.dart';
import 'public_study_tools.dart';
import 'send_error_message.dart';
import 'session_store.dart';
import 'timetable_repository.dart';
import 'talks_client.dart';
import 'talks_repository.dart';
import 'voice_controller.dart';

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
    required OnboardingProfile? initialProfile,
    required VoidCallback? initialOnLogout,
    required Future<void> Function(OnboardingProfile profile)?
    initialOnSaveProfile,
    this.onOpenChatRequest,
    NativeBridge? nativeBridge,
    TalksRepository? talksRepository,
    CalendarOverviewSource? calendarOverviewSource,
  }) : bridge = nativeBridge ?? NativeBridge(),
       talksRepository = talksRepository ?? TalksRepository(),
       _ownsTalksRepository = talksRepository == null,
       _profile = initialProfile,
       _onLogout = initialOnLogout,
       _onSaveProfile = initialOnSaveProfile {
    _privateStudyTools = CombinedPrivateStudyToolRunner(
      portal: LivePrivateStudyToolRunner(
        PrivateStudyCapability(profileProvider: () => _profile),
      ),
      alma: LiveAlmaStudyToolRunner(
        AlmaStudyCapability(profileProvider: () => _profile),
      ),
    );
    this.calendarOverviewSource =
        calendarOverviewSource ??
        CalendarOverviewRepository(bridge, this.talksRepository);
  }

  final NativeBridge bridge;
  final TalksRepository talksRepository;
  final bool _ownsTalksRepository;
  late final CalendarOverviewSource calendarOverviewSource;
  final SessionStore _sessionStore = SessionStore();
  final AgentConfigStore _configStore = AgentConfigStore();
  final MailRepository _mailRepository = MailRepository();
  final MemoryStore _memoryStore = MemoryStore();
  final TimetableRepository _timetableRepository = TimetableRepository();
  final AcademicRepository _academicRepository = AcademicRepository();
  final OfficialDocumentsRepository _documentsRepository =
      OfficialDocumentsRepository();
  final PublicStudyToolRunner _publicStudyTools = LivePublicStudyToolRunner();
  late final PrivateStudyToolRunner _privateStudyTools;
  final TextEditingController inputController = TextEditingController();
  final ScrollController messageScrollController = ScrollController();

  /// In-app voice prototype: speech capture, live transcript, and TTS of
  /// replies. Reaches the send pipeline through [inputController] + [sendMessage].
  late final VoiceController voice = VoiceController(
    inputController: inputController,
    onSend: sendMessage,
  );

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
  AcademicStatusSnapshot? _academicStatus;
  String? _academicStatusError;
  String? _academicReportError;
  List<OfficialDocument> _officialDocuments = <OfficialDocument>[];
  String? _officialDocumentsError;
  String? _timetableError;
  String? _calendarSyncMessage;
  String? _calendarSyncError;
  Map<String, Object?> _worldState = const {};
  String _status = 'Starting';
  bool _isSending = false;
  bool _compactMessages = false;
  bool _isRefreshingTimetable = false;
  bool _isRefreshingAcademicStatus = false;
  bool _isOpeningAcademicReport = false;
  bool _isLoadingOfficialDocuments = false;
  String? _openingOfficialDocumentId;
  bool _isSyncingCalendar = false;
  StreamingAssistantMessage? _streaming;
  Timer? _streamNotifyTimer;
  AgentCancelToken? _cancelToken;

  OnboardingProfile? get profile => _profile;
  VoidCallback? get onLogout => _onLogout;
  List<ChatSession> get sessions => _sessions;
  String? get activeSessionId => _activeSessionId;
  AgentConfig get agentConfig => _agentConfig;
  String get memoryText => _memoryText;
  TimetableSnapshot? get timetable => _timetable;
  AcademicStatusSnapshot? get academicStatus => _academicStatus;
  String? get academicStatusError => _academicStatusError;
  String? get academicReportError => _academicReportError;
  List<OfficialDocument> get officialDocuments => _officialDocuments;
  String? get officialDocumentsError => _officialDocumentsError;
  HomeFeedSnapshot get homeFeedSnapshot => HomeFeedSnapshot.fromLocalState(
    profile: _profile,
    timetable: _timetable,
    memoryText: _memoryText,
    now: DateTime.now(),
  );
  String? get timetableError => _timetableError;
  String? get calendarSyncMessage => _calendarSyncMessage;
  String? get calendarSyncError => _calendarSyncError;
  Map<String, Object?> get worldState => _worldState;
  String get status => _status;
  bool get isSending => _isSending;
  bool get compactMessages => _compactMessages;
  bool get isRefreshingTimetable => _isRefreshingTimetable;
  bool get isRefreshingAcademicStatus => _isRefreshingAcademicStatus;
  bool get isOpeningAcademicReport => _isOpeningAcademicReport;
  bool get isLoadingOfficialDocuments => _isLoadingOfficialDocuments;
  String? get openingOfficialDocumentId => _openingOfficialDocumentId;
  bool get isSyncingCalendar => _isSyncingCalendar;

  /// The reply currently streaming in, or null when none is in flight. The chat
  /// UI renders a live bubble from this.
  StreamingAssistantMessage? get streaming => _streaming;

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
    unawaited(refreshAcademicStatus());
    unawaited(_initializeNativeLayer());
    unawaited(voice.init());
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
    _privateStudyTools.invalidate();
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
    _streamNotifyTimer?.cancel();
    _eventSubscription?.cancel();
    voice.dispose();
    _publicStudyTools.close();
    if (_ownsTalksRepository) talksRepository.dispose();
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
    if (event.type == 'assistantDelta') {
      _handleStreamDelta(
        AgentStreamDelta(content: event.message, reset: event.reset),
      );
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
    unawaited(refreshAcademicStatus());
  }

  Future<void> refreshAcademicStatus() async {
    final profile = _profile;
    if (profile == null || _isRefreshingAcademicStatus) return;
    _isRefreshingAcademicStatus = true;
    _academicStatusError = null;
    _notify();
    try {
      // Use the term-aware ALMA enrollment overview for the status snapshot.
      // The official registration report (PDF, native `extractPdfText`) stays
      // behind the explicit report-download action so this works on every
      // platform, not only where the native PDF extractor is implemented.
      _academicStatus = await _academicRepository.refresh(profile);
    } on Object catch (error) {
      _academicStatusError = error.toString();
    } finally {
      _isRefreshingAcademicStatus = false;
      _notify();
    }
  }

  Future<void> openAcademicReport() async {
    final profile = _profile;
    if (profile == null || _isOpeningAcademicReport) return;
    _isOpeningAcademicReport = true;
    _academicReportError = null;
    _notify();
    try {
      final document = await _academicRepository.downloadRegistrationReport(
        profile,
      );
      await bridge.previewPdf(
        document: document,
        filename: 'alma-registrations.pdf',
      );
    } on Object catch (error) {
      _academicReportError = error.toString();
    } finally {
      _isOpeningAcademicReport = false;
      _notify();
    }
  }

  Future<void> loadOfficialDocuments() async {
    final profile = _profile;
    if (profile == null || _isLoadingOfficialDocuments) return;
    _isLoadingOfficialDocuments = true;
    _officialDocumentsError = null;
    _notify();
    try {
      _officialDocuments = await _documentsRepository.list(profile);
    } on Object catch (error) {
      _officialDocumentsError = error.toString();
    } finally {
      _isLoadingOfficialDocuments = false;
      _notify();
    }
  }

  Future<void> openOfficialDocument(OfficialDocument document) async {
    final profile = _profile;
    if (profile == null || _openingOfficialDocumentId != null) return;
    _openingOfficialDocumentId = document.id;
    _officialDocumentsError = null;
    _notify();
    try {
      final pdf = await _documentsRepository.download(profile, document);
      await bridge.previewPdf(
        document: pdf,
        filename: _documentFilename(document.label),
      );
    } on Object catch (error) {
      _officialDocumentsError = error.toString();
    } finally {
      _openingOfficialDocumentId = null;
      _notify();
    }
  }

  String _documentFilename(String label) {
    final stem = label
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '')
        .toLowerCase();
    return 'alma-${stem.isEmpty ? 'document' : stem}.pdf';
  }

  Future<String> readAcademicStatusForAgent() async {
    final status = _academicStatus;
    if (status == null) {
      await refreshAcademicStatus();
    }
    final resolved = _academicStatus;
    if (resolved == null) {
      return _academicStatusError ?? 'Academic status is not available.';
    }
    return jsonEncode(<String, Object?>{
      'term': resolved.term,
      'available_terms': resolved.availableTerms,
      'refreshed_at': resolved.refreshedAt.toIso8601String(),
      'notice': resolved.notice,
      'entries': resolved.entries.map((entry) => entry.toJson()).toList(),
    });
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
    _streaming = StreamingAssistantMessage();
    voice.beginSpokenReply();
    final cancelToken = AgentCancelToken();
    _cancelToken = cancelToken;
    _notify();

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
        readAcademicStatus: readAcademicStatusForAgent,
        searchTalks: searchTalksForAgent,
        mailTools: MailToolRunner(
          repository: _mailRepository,
          profile: _profile,
        ),
        publicStudyTools: _publicStudyTools,
        privateStudyTools: _privateStudyTools,
        onToolTrace: addToolTrace,
        onDelta: _handleStreamDelta,
        cancelToken: cancelToken,
      );
      final reasoning = _finishStreaming();
      addAssistantMessage(response, reasoning: reasoning);
      await _loadMemory();
      final worldState = await bridge.getWorldState();
      if (_disposed) return;
      _worldState = withProfileContext(
        worldState,
        _profile,
        timetable: _timetable,
      );
      _notify();
    } on AgentCancelledException {
      _commitStreamingPartial();
    } on Object catch (error) {
      _finishStreaming();
      final message = sendErrorMessage(error);
      if (message == null) rethrow;
      addAssistantMessage(message);
    } finally {
      _cancelToken = null;
      if (!_disposed) {
        _isSending = false;
        _notify();
      }
    }
  }

  /// Stops the in-flight reply. Aborts the cloud HTTP stream via the cancel
  /// token and asks the native bridge to cancel any local generation.
  void cancelMessage() {
    if (!_isSending) return;
    _cancelToken?.cancel();
    unawaited(_cancelLocalGeneration());
  }

  Future<void> _cancelLocalGeneration() async {
    try {
      await bridge.cancelMessage();
    } on MissingPluginException {
      // No native bridge on this platform (e.g. desktop): nothing to cancel.
    } on PlatformException catch (error) {
      debugPrint('Local cancel failed: ${error.message}');
    }
  }

  /// Finalizes a cancelled reply by committing whatever streamed in so far.
  void _commitStreamingPartial() {
    if (_disposed) return;
    final streaming = _streaming;
    final reasoning = _finishStreaming();
    final partial = streaming?.text.trim() ?? '';
    if (partial.isNotEmpty) {
      addAssistantMessage(partial, reasoning: reasoning);
    }
  }

  /// Applies one streamed fragment to the in-flight reply. Cloud deltas arrive
  /// through the [AgentStreamSink]; local (native) deltas arrive as
  /// `assistantDelta` events and are routed here too.
  void _handleStreamDelta(AgentStreamDelta delta) {
    final streaming = _streaming;
    if (streaming == null || _disposed) return;
    if (delta.reset) streaming.resetContent();
    final content = delta.content;
    final hasContent = content != null && content.isNotEmpty;
    if (hasContent) streaming.addContent(content);
    final reasoning = delta.reasoning;
    if (reasoning != null && reasoning.isNotEmpty) {
      streaming.addReasoning(reasoning);
    }
    // Schedule the on-screen update first; only then feed the voice engine, and
    // only when this reply is actually being spoken. Keeping it after the notify
    // (and out of the common typed-message path) ensures TTS can never delay or
    // interfere with the live streaming text.
    _scheduleStreamNotify();
    if (hasContent && voice.isVoicingReply) {
      voice.pushReplyText(streaming.text);
    }
  }

  /// Coalesces frequent streaming updates into ~30fps repaints so token bursts
  /// don't trigger a rebuild per token.
  void _scheduleStreamNotify() {
    if (_streamNotifyTimer != null || _disposed) return;
    _streamNotifyTimer = Timer(const Duration(milliseconds: 33), () {
      _streamNotifyTimer = null;
      if (_disposed) return;
      notifyListeners();
      maybeStickChatToBottom(messageScrollController);
    });
  }

  /// Tears down streaming state and returns the accumulated reasoning (or null).
  String? _finishStreaming() {
    _streamNotifyTimer?.cancel();
    _streamNotifyTimer = null;
    final streaming = _streaming;
    _streaming = null;
    if (streaming == null) return null;
    final reasoning = streaming.reasoning.trim();
    return reasoning.isEmpty ? null : reasoning;
  }

  void addAssistantMessage(String text, {String? reasoning}) {
    if (_disposed) return;
    appendMessage(
      ChatMessage(
        author: 'StudyOS Agent',
        text: text,
        isUser: false,
        reasoning: reasoning,
      ),
    );
    _status = text;
    _notify();
    unawaited(HapticFeedback.lightImpact());
    voice.endSpokenReply(text);
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

  Future<void> syncTimetableToCalendar() async {
    if (_isSyncingCalendar) return;
    final snapshot = _timetable;
    if (snapshot == null) {
      _calendarSyncMessage = null;
      _calendarSyncError = 'Refresh ALMA before syncing calendar.';
      _notify();
      return;
    }

    _isSyncingCalendar = true;
    _calendarSyncMessage = null;
    _calendarSyncError = null;
    _notify();

    try {
      final message = await bridge.syncScheduleToCalendar(snapshot);
      if (_disposed) return;
      _calendarSyncMessage = message;
      _status = message;
    } on MissingPluginException {
      if (!_disposed) {
        _calendarSyncError = 'Calendar sync is not supported on this platform.';
      }
    } on PlatformException catch (error) {
      if (!_disposed) {
        _calendarSyncError = error.message ?? 'Calendar sync failed.';
      }
    } on Object catch (error) {
      if (!_disposed) {
        _calendarSyncError = error.toString();
      }
    } finally {
      if (!_disposed) {
        _isSyncingCalendar = false;
        _notify();
      }
    }
  }

  Future<void> refreshHomeFeed() async {
    await refreshTimetable();
    await _loadMemory();
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

  Future<String> searchTalksForAgent(String query, int limit) async {
    final talks = await talksRepository.load();
    final matches = talks.where((talk) => talk.matches(query)).take(limit);
    return jsonEncode(<String, Object?>{
      'scope': 'upcoming',
      'query': query,
      'source_url': TalksClient.sourceUri.toString(),
      'items': matches.map((talk) => talk.toJson()).toList(),
    });
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
      // A pending intent means another app (assist gesture, voice command, share
      // sheet) explicitly handed StudyOS a request to act on, so auto-send it —
      // matching the foreground `voicePrompt` path rather than just prefilling.
      onOpenChatRequest?.call(ChatRouteRequest(prompt: text, autosend: true));
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
