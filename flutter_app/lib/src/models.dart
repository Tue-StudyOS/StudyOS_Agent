import 'dart:convert';

class ChatMessage {
  const ChatMessage({
    required this.author,
    required this.text,
    required this.isUser,
  });

  final String author;
  final String text;
  final bool isUser;

  Map<String, Object?> toJson() {
    return <String, Object?>{'author': author, 'text': text, 'isUser': isUser};
  }

  static ChatMessage fromJson(Map<String, Object?> json) {
    return ChatMessage(
      author: json['author']?.toString() ?? 'StudyOS Agent',
      text: json['text']?.toString() ?? '',
      isUser: json['isUser'] == true,
    );
  }
}

enum AppView { chat, memories, settings }

enum AgentProvider { local, cloud }

class AgentConfig {
  const AgentConfig({
    required this.provider,
    required this.cloudEndpoint,
    required this.cloudModel,
    required this.hasApiKey,
  });

  const AgentConfig.defaults()
    : provider = AgentProvider.local,
      cloudEndpoint = '',
      cloudModel = '',
      hasApiKey = false;

  final AgentProvider provider;
  final String cloudEndpoint;
  final String cloudModel;
  final bool hasApiKey;

  bool get usesCloud => provider == AgentProvider.cloud;

  AgentConfig copyWith({
    AgentProvider? provider,
    String? cloudEndpoint,
    String? cloudModel,
    bool? hasApiKey,
  }) {
    return AgentConfig(
      provider: provider ?? this.provider,
      cloudEndpoint: cloudEndpoint ?? this.cloudEndpoint,
      cloudModel: cloudModel ?? this.cloudModel,
      hasApiKey: hasApiKey ?? this.hasApiKey,
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
  });

  factory NativeEvent.fromMap(Map<String, Object?> map) {
    return NativeEvent(
      type: map['type']?.toString() ?? 'status',
      message: map['message']?.toString() ?? '',
      timestamp: map['timestamp']?.toString() ?? '',
    );
  }

  final String type;
  final String message;
  final String timestamp;
}
