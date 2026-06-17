import 'dart:convert';

import 'tool_trace.dart';

export 'student_profile.dart';
export 'mail_models.dart';
export 'timetable_models.dart';
export 'tool_trace.dart';

class ChatMessage {
  const ChatMessage({
    required this.author,
    required this.text,
    required this.isUser,
    this.trace,
  });

  ChatMessage.toolTrace({
    required String toolName,
    required String status,
    required String summary,
    String? callId,
  }) : author = 'Tool',
       text = summary,
       isUser = false,
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

  bool get isTrace => trace != null;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'author': author,
      'text': text,
      'isUser': isUser,
      if (trace != null) 'trace': trace!.toJson(),
    };
  }

  static ChatMessage fromJson(Map<String, Object?> json) {
    final rawTrace = json['trace'];
    final trace = rawTrace is Map
        ? ToolTrace.fromJson(Map<String, Object?>.from(rawTrace))
        : null;
    return ChatMessage(
      author: json['author']?.toString() ?? 'StudyOS Agent',
      text: json['text']?.toString() ?? '',
      isUser: json['isUser'] == true,
      trace: trace,
    );
  }
}

enum AppView { home, chat, schedule, mail, maps, campus, memories, settings }

enum AgentProvider { local, cloud }

class AgentConfig {
  const AgentConfig({
    required this.provider,
    required this.cloudEndpoint,
    required this.cloudModel,
    required this.hasApiKey,
    required this.localModelId,
    required this.localModelPath,
  });

  const AgentConfig.defaults()
    : provider = AgentProvider.local,
      cloudEndpoint = '',
      cloudModel = '',
      hasApiKey = false,
      localModelId = 'gemma-4-e2b-it',
      localModelPath = '';

  final AgentProvider provider;
  final String cloudEndpoint;
  final String cloudModel;
  final bool hasApiKey;
  final String localModelId;
  final String localModelPath;

  bool get usesCloud => provider == AgentProvider.cloud;

  AgentConfig copyWith({
    AgentProvider? provider,
    String? cloudEndpoint,
    String? cloudModel,
    bool? hasApiKey,
    String? localModelId,
    String? localModelPath,
  }) {
    return AgentConfig(
      provider: provider ?? this.provider,
      cloudEndpoint: cloudEndpoint ?? this.cloudEndpoint,
      cloudModel: cloudModel ?? this.cloudModel,
      hasApiKey: hasApiKey ?? this.hasApiKey,
      localModelId: localModelId ?? this.localModelId,
      localModelPath: localModelPath ?? this.localModelPath,
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
