import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'agent_config_store.dart';
import 'agent_message_sender.dart';
import 'academic_repository.dart';
import 'calendar_overview_repository.dart';
import 'chat_scroll.dart';
import 'chat_session_mutation.dart';
import 'generated_ui_message.dart';
import 'mail_repository.dart';
import 'mail_tools.dart';
import 'memory_store.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'native_tool_router.dart';
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

/// Chooses when a deadline reminder should fire: one day before the due time,
/// stepping closer (one hour before, then a short delay) as the deadline nears
/// so the reminder never lands in the past. Pure so it can be unit-tested.
DateTime reminderTimeForDeadline(DateTime dueAt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final dayBefore = dueAt.subtract(const Duration(days: 1));
  if (dayBefore.isAfter(reference)) return dayBefore;
  final hourBefore = dueAt.subtract(const Duration(hours: 1));
  if (hourBefore.isAfter(reference)) return hourBefore;
  return reference.add(const Duration(minutes: 10));
}

/// Builds the Google Maps search URL for coordinates. Mirrors the deep link the
/// in-app map view uses for its "Open in maps" control, so both surfaces behave
/// identically. Pure so it can be unit-tested.
Uri campusMapsUri(double latitude, double longitude) {
  return Uri.https('www.google.com', '/maps/search/', <String, String>{
    'api': '1',
    'query': '$latitude,$longitude',
  });
}

Future<bool> _launchExternal(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
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
    NativeToolRunner? nativeToolRunner,
    AcademicRepository? academicRepository,
    TimetableRepository? timetableRepository,
    Future<bool> Function(Uri uri)? urlLauncher,
  }) : bridge = nativeBridge ?? NativeBridge(),
       talksRepository = talksRepository ?? TalksRepository(),
       _ownsTalksRepository = talksRepository == null,
       _academicRepository = academicRepository ?? AcademicRepository(),
       _timetableRepository = timetableRepository ?? TimetableRepository(),
       _urlLauncher = urlLauncher ?? _launchExternal,
       _profile = initialProfile,
       _onLogout = initialOnLogout,
       _onSaveProfile = initialOnSaveProfile {
    _nativeToolRunner = nativeToolRunner ?? NativeToolRouter(bridge);
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
  late final NativeToolRunner _nativeToolRunner;
  final Future<bool> Function(Uri uri) _urlLauncher;
  final TalksRepository talksRepository;
  final bool _ownsTalksRepository;
  late final CalendarOverviewSource calendarOverviewSource;
  final SessionStore _sessionStore = SessionStore();
  final AgentConfigStore _configStore = AgentConfigStore();
  final MailRepository _mailRepository = MailRepository();

  /// Shared mail repository so the mail view reuses the cached IMAP session.
  MailRepository get mailRepository => _mailRepository;
  final MemoryStore _memoryStore = MemoryStore();
  final TimetableRepository _timetableRepository;
  final AcademicRepository _academicRepository;
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
  Future<void>? _timetableRefresh;
  AcademicStatusSnapshot? _academicStatus;
  String? _academicStatusError;
  Future<void>? _academicStatusRefresh;
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

  /// Generative-UI card payloads produced by tools during the in-flight turn,
  /// keyed by tool name (last call of each tool wins). Nothing is shown just
  /// because a tool ran: a card surfaces only if the assistant's final reply
  /// references it with a `tool_card` block, which is resolved against this map
  /// when the message is committed (see [addAssistantMessage]). Cleared at the
  /// start of every turn.
  final Map<String, Map<String, Object?>> _turnToolComponents =
      <String, Map<String, Object?>>{};

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

  Future<void> refreshAcademicStatus() {
    final profile = _profile;
    if (profile == null) return Future<void>.value();
    // Coalesce concurrent refreshes so callers await the in-flight fetch
    // instead of racing past a still-running one. Previously the guard made a
    // second caller (e.g. the get_academic_status tool, fired while the
    // background refresh started in initialize() was still running) return
    // immediately and read a null snapshot — surfacing "Academic status is not
    // available." and masking the real error. Callers now share one future.
    return _academicStatusRefresh ??= _runAcademicStatusRefresh(
      profile,
    ).whenComplete(() => _academicStatusRefresh = null);
  }

  Future<void> _runAcademicStatusRefresh(OnboardingProfile profile) async {
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
    if (_profile == null) {
      return 'Academic status is unavailable: no student profile is signed in.';
    }
    if (_academicStatus == null) {
      await refreshAcademicStatus();
    }
    final resolved = _academicStatus;
    if (resolved == null) {
      // The refresh finished without a snapshot; surface the real reason
      // (e.g. an authentication prompt) instead of a generic string.
      return _academicStatusError ??
          'Academic status could not be loaded right now. Please try again in a moment.';
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

  /// Dispatches an action emitted by an interactive generative-UI component.
  /// Prompt actions go back through the agent; reminder actions create a native
  /// device reminder directly (the tap is the user's authorization).
  void handleComponentAction(GeneratedComponentAction action) {
    switch (action) {
      case PromptComponentAction(:final prompt):
        unawaited(runComponentPrompt(prompt));
      case ReminderComponentAction(:final title, :final dueAt):
        unawaited(addDeadlineReminder(title: title, dueAt: dueAt));
      case MapComponentAction(:final name, :final latitude, :final longitude):
        unawaited(
          openLocationInMaps(
            name: name,
            latitude: latitude,
            longitude: longitude,
          ),
        );
    }
  }

  /// Runs a prompt requested by a component (e.g. mail Summarize): prefills the
  /// composer and sends it, reusing the autosent chat-route path so a turn is
  /// created immediately.
  Future<void> runComponentPrompt(String text) {
    return applyChatRoute(prompt: text, autosend: true);
  }

  /// Creates a native device reminder ahead of [dueAt] via the capability-gated
  /// native tool runner, then reports the outcome as an assistant message. On
  /// platforms without reminder support the runner returns a friendly message,
  /// which is surfaced as-is.
  Future<void> addDeadlineReminder({
    required String title,
    required DateTime dueAt,
  }) async {
    final when = reminderTimeForDeadline(dueAt);
    final result = await _nativeToolRunner.execute(
      nativeCreateReminderToolName,
      jsonEncode(<String, Object?>{
        'title': title,
        'time': when.toIso8601String(),
      }),
    );
    if (_disposed) return;
    final detail = result.trim();
    addAssistantMessage(
      detail.isEmpty ? 'Reminder requested for "$title".' : detail,
    );
  }

  /// Opens a geocoded place in the device's external maps app. Reports a message
  /// only on failure (success hands off to the maps app).
  Future<void> openLocationInMaps({
    required String name,
    required double latitude,
    required double longitude,
  }) async {
    bool opened;
    try {
      opened = await _urlLauncher(campusMapsUri(latitude, longitude));
    } on Object {
      opened = false;
    }
    if (_disposed) return;
    if (!opened) {
      addAssistantMessage('Could not open $name in maps.');
    }
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
    _turnToolComponents.clear();
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
      // Never speak the trailing `ui` component block.
      voice.pushReplyText(streamingVisibleText(streaming.text));
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
    // Split off any model-emitted `ui` block (always stripped from the visible
    // text so raw JSON is never shown), then decide the card: an explicit
    // reference or composed component if present, else the most recent tool
    // card when the reply reads as a short lead-in. A long pivot answer that
    // merely ran a tool gets no card.
    final parts = splitAssistantComponent(text);
    final component = resolveMessageComponent(
      emitted: parts.component,
      capturedToolComponents: _turnToolComponents,
      replyText: parts.text,
    );
    _turnToolComponents.clear();
    appendMessage(
      ChatMessage(
        author: 'StudyOS Agent',
        text: parts.text,
        isUser: false,
        reasoning: reasoning,
        component: component,
      ),
    );
    _status = parts.text;
    _notify();
    unawaited(HapticFeedback.lightImpact());
    voice.endSpokenReply(parts.text);
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
    // Capture a tool's card payload for the turn, keyed by tool name. It is only
    // shown if the assistant's final reply opts it in with a `tool_card`
    // reference — running the tool alone never surfaces a card.
    final component = trace.component;
    if (component != null) {
      _turnToolComponents[trace.toolName] = component;
    }
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

  Future<void> refreshTimetable() {
    final profile = _profile;
    if (profile == null) {
      _timetableError = 'Sign in again to refresh your timetable.';
      _notify();
      return Future<void>.value();
    }
    // Coalesce concurrent refreshes so a caller (e.g. the get_schedule tool)
    // awaits the in-flight fetch instead of racing past it — same fix as
    // academic status.
    return _timetableRefresh ??= _runTimetableRefresh(
      profile,
    ).whenComplete(() => _timetableRefresh = null);
  }

  Future<void> _runTimetableRefresh(OnboardingProfile profile) async {
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
    if (snapshot == null || snapshot.events.isEmpty) {
      return _timetableError ?? 'No timetable has been synced yet.';
    }
    final upcoming = snapshot.upcoming.take(12).toList(growable: false);
    if (upcoming.isEmpty) {
      return 'No upcoming lectures in the synced timetable.';
    }
    // Structured output so the client can render an interactive schedule card
    // (see schedule_agenda in GenerativeUiRegistry). The model gets the same
    // data as JSON instead of a prose summary.
    return jsonEncode(<String, Object?>{
      'source_term': snapshot.sourceTerm,
      'refreshed_at': snapshot.refreshedAt.toIso8601String(),
      'events': upcoming
          .map(
            (event) => <String, Object?>{
              'title': event.title,
              'start': event.start.toIso8601String(),
              'end': event.end?.toIso8601String(),
              'location': event.location,
            },
          )
          .toList(growable: false),
    });
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
