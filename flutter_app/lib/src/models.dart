import 'dart:async';
import 'dart:convert';

import 'tool_trace.dart';

export 'student_profile.dart';
export 'mail_models.dart';
export 'feed_summary.dart';
export 'timetable_models.dart';
export 'tool_trace.dart';

/// A fragment of a streamed assistant turn. [content] carries answer text,
/// [reasoning] carries a "thinking" fragment, and [reset] signals the live
/// buffer should be cleared (e.g. pre-tool content is discarded before the
/// follow-up answer streams).
class AgentStreamDelta {
  const AgentStreamDelta({this.content, this.reasoning, this.reset = false});

  final String? content;
  final String? reasoning;
  final bool reset;
}

/// Sink that receives [AgentStreamDelta]s as an assistant reply streams in.
typedef AgentStreamSink = void Function(AgentStreamDelta delta);

/// Raised when an in-flight reply is cancelled by the user (Stop button).
class AgentCancelledException implements Exception {
  const AgentCancelledException();

  @override
  String toString() => 'The request was cancelled.';
}

/// Cooperative cancellation handle for an in-flight assistant request. The
/// controller holds one per send and calls [cancel] when the user taps Stop;
/// the cloud client aborts its streaming subscription via [whenCancelled].
class AgentCancelToken {
  final Completer<void> _completer = Completer<void>();
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  /// Completes the moment [cancel] is first called.
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    if (!_completer.isCompleted) _completer.complete();
  }
}

/// Mutable accumulator for the in-progress assistant reply. The controller
/// owns one while a reply streams; the UI renders a live bubble from it.
class StreamingAssistantMessage {
  final StringBuffer _text = StringBuffer();
  final StringBuffer _reasoning = StringBuffer();

  String get text => _text.toString();
  String get reasoning => _reasoning.toString();
  bool get hasText => _text.isNotEmpty;
  bool get hasReasoning => _reasoning.isNotEmpty;

  void addContent(String fragment) => _text.write(fragment);
  void addReasoning(String fragment) => _reasoning.write(fragment);

  /// Discards accumulated answer text (e.g. a pre-tool turn) while keeping any
  /// reasoning gathered so far.
  void resetContent() => _text.clear();
}

class ChatMessage {
  const ChatMessage({
    required this.author,
    required this.text,
    required this.isUser,
    this.trace,
    this.reasoning,
  });

  ChatMessage.toolTrace({
    required String toolName,
    required String status,
    required String summary,
    String? callId,
  }) : author = 'Tool',
       text = summary,
       isUser = false,
       reasoning = null,
       trace = ToolTrace(
         toolName: toolName,
         status: status,
         summary: summary,
         callId: callId,
       );

  final String author;
  final String text;
  final bool isUser;
  final ToolTrace? trace;

  /// Optional model "thinking"/reasoning trace, shown in a collapsed panel.
  final String? reasoning;

  bool get isTrace => trace != null;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'author': author,
      'text': text,
      'isUser': isUser,
      if (trace != null) 'trace': trace!.toJson(),
      if (reasoning != null && reasoning!.isNotEmpty) 'reasoning': reasoning,
    };
  }

  static ChatMessage fromJson(Map<String, Object?> json) {
    final rawTrace = json['trace'];
    final trace = rawTrace is Map
        ? ToolTrace.fromJson(Map<String, Object?>.from(rawTrace))
        : null;
    final reasoning = json['reasoning']?.toString();
    return ChatMessage(
      author: json['author']?.toString() ?? 'StudyOS Agent',
      text: json['text']?.toString() ?? '',
      isUser: json['isUser'] == true,
      trace: trace,
      reasoning: reasoning == null || reasoning.isEmpty ? null : reasoning,
    );
  }
}

enum AgentProvider { local, cloud }

/// Accelerator preference for the on-device (LiteRT-LM) model. [gpu] prefers the
/// GPU and falls back to CPU when GPU init fails; [cpu] forces CPU only.
enum LocalBackend { gpu, cpu }

/// Parses a persisted/native backend name, defaulting to [LocalBackend.gpu].
LocalBackend localBackendFromName(String? name) {
  return name == LocalBackend.cpu.name ? LocalBackend.cpu : LocalBackend.gpu;
}

class AgentConfig {
  const AgentConfig({
    required this.provider,
    required this.cloudEndpoint,
    required this.cloudModel,
    required this.hasApiKey,
    required this.localModelId,
    required this.localModelPath,
    this.localBackend = LocalBackend.gpu,
  });

  const AgentConfig.defaults()
    : provider = AgentProvider.local,
      cloudEndpoint = '',
      cloudModel = '',
      hasApiKey = false,
      localModelId = 'gemma-4-e2b-it',
      localModelPath = '',
      localBackend = LocalBackend.gpu;

  final AgentProvider provider;
  final String cloudEndpoint;
  final String cloudModel;
  final bool hasApiKey;
  final String localModelId;
  final String localModelPath;
  final LocalBackend localBackend;

  bool get usesCloud => provider == AgentProvider.cloud;

  AgentConfig copyWith({
    AgentProvider? provider,
    String? cloudEndpoint,
    String? cloudModel,
    bool? hasApiKey,
    String? localModelId,
    String? localModelPath,
    LocalBackend? localBackend,
  }) {
    return AgentConfig(
      provider: provider ?? this.provider,
      cloudEndpoint: cloudEndpoint ?? this.cloudEndpoint,
      cloudModel: cloudModel ?? this.cloudModel,
      hasApiKey: hasApiKey ?? this.hasApiKey,
      localModelId: localModelId ?? this.localModelId,
      localModelPath: localModelPath ?? this.localModelPath,
      localBackend: localBackend ?? this.localBackend,
    );
  }
}

class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  factory ChatSession.fresh() {
    final now = DateTime.now();
    return ChatSession(
      id: 'chat-${now.microsecondsSinceEpoch}',
      title: 'New chat',
      updatedAt: now,
      messages: const <ChatMessage>[],
    );
  }

  final String id;
  final String title;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  String get shortId => id.length > 10 ? id.substring(id.length - 10) : id;
  bool get hasTurns => messages.any((message) => !message.isTrace);
  ChatSession copyWith({
    String? title,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'updatedAt': updatedAt.toIso8601String(),
      'messages': messages.map((message) => message.toJson()).toList(),
    };
  }

  static ChatSession fromJson(Map<String, Object?> json) {
    final rawMessages = json['messages'];
    final messages = rawMessages is List
        ? rawMessages
              .whereType<Map>()
              .map(
                (item) => ChatMessage.fromJson(Map<String, Object?>.from(item)),
              )
              .toList()
        : <ChatMessage>[];

    return ChatSession(
      id: json['id']?.toString() ?? ChatSession.fresh().id,
      title: json['title']?.toString() ?? 'New chat',
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      messages: messages,
    );
  }

  static List<ChatSession> decodeList(String? value) {
    if (value == null || value.isEmpty) return <ChatSession>[];
    final decoded = jsonDecode(value);
    if (decoded is! List) return <ChatSession>[];
    return decoded
        .whereType<Map>()
        .map((item) => ChatSession.fromJson(Map<String, Object?>.from(item)))
        .toList();
  }

  static String encodeList(List<ChatSession> sessions) {
    return jsonEncode(sessions.map((session) => session.toJson()).toList());
  }
}

class NativeEvent {
  const NativeEvent({
    required this.type,
    required this.message,
    required this.timestamp,
    this.modelId,
    this.progress,
    this.bytesReceived,
    this.totalBytes,
    this.trace,
    this.reset = false,
  });

  factory NativeEvent.fromMap(Map<String, Object?> map) {
    final rawTrace = map['trace'];
    return NativeEvent(
      type: map['type']?.toString() ?? 'status',
      message: map['message']?.toString() ?? '',
      timestamp: map['timestamp']?.toString() ?? '',
      modelId: map['modelId']?.toString(),
      progress: _toDouble(map['progress']),
      bytesReceived: _toInt(map['bytesReceived']),
      totalBytes: _toInt(map['totalBytes']),
      trace: rawTrace is Map
          ? ToolTrace.fromJson(Map<String, Object?>.from(rawTrace))
          : null,
      reset: map['reset'] == true,
    );
  }

  final String type;
  final String message;
  final String timestamp;
  final String? modelId;
  final double? progress;
  final int? bytesReceived;
  final int? totalBytes;
  final ToolTrace? trace;

  /// For `assistantDelta` events: clear the live streaming buffer before
  /// applying [message] (used between tool rounds).
  final bool reset;

  static double? _toDouble(Object? value) {
    return switch (value) {
      double amount => amount,
      int amount => amount.toDouble(),
      String text => double.tryParse(text),
      _ => null,
    };
  }

  static int? _toInt(Object? value) {
    return switch (value) {
      int amount => amount,
      double amount => amount.round(),
      String text => int.tryParse(text),
      _ => null,
    };
  }
}
