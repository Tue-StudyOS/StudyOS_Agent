import 'dart:convert';

import 'tool_trace.dart';

export 'tool_trace.dart';

class UserSession {
  const UserSession({
    required this.username,
    this.displayName,
    this.email,
    this.degreeProgram,
    this.profileWarning,
  });

  final String username;
  final String? displayName;
  final String? email;
  final String? degreeProgram;
  final String? profileWarning;

  String get suggestedDisplayName {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.trim();
    }
    final cleaned = username
        .split('@')
        .first
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .trim();
    if (cleaned.isEmpty) return '';
    return cleaned
        .split(RegExp(r'\s+'))
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String? get displayEmail {
    if (email != null && email!.contains('@')) return email;
    return username.contains('@') ? username : null;
  }
}

class OnboardingProfile {
  const OnboardingProfile({
    required this.displayName,
    required this.username,
    required this.email,
    required this.degreeProgram,
    required this.semester,
    required this.livesInTuebingen,
  });

  final String displayName;
  final String username;
  final String? email;
  final String degreeProgram;
  final int? semester;
  final bool livesInTuebingen;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'displayName': displayName,
      'username': username,
      'email': email,
      'degreeProgram': degreeProgram,
      'semester': semester,
      'livesInTuebingen': livesInTuebingen,
    };
  }

  static OnboardingProfile? fromJson(Map<String, Object?> json) {
    final displayName = json['displayName']?.toString().trim();
    final username = json['username']?.toString().trim();
    final degreeProgram = json['degreeProgram']?.toString().trim();
    if (displayName == null ||
        displayName.isEmpty ||
        username == null ||
        username.isEmpty ||
        degreeProgram == null ||
        degreeProgram.isEmpty) {
      return null;
    }

    final semesterValue = json['semester'];
    return OnboardingProfile(
      displayName: displayName,
      username: username,
      email: json['email']?.toString(),
      degreeProgram: degreeProgram,
      semester: semesterValue is int
          ? semesterValue
          : int.tryParse(semesterValue?.toString() ?? ''),
      livesInTuebingen: json['livesInTuebingen'] == true,
    );
  }
}

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

enum AppView { home, chat, schedule, memories, settings }

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
    this.trace,
  });

  factory NativeEvent.fromMap(Map<String, Object?> map) {
    final rawTrace = map['trace'];
    return NativeEvent(
      type: map['type']?.toString() ?? 'status',
      message: map['message']?.toString() ?? '',
      timestamp: map['timestamp']?.toString() ?? '',
      trace: rawTrace is Map
          ? ToolTrace.fromJson(Map<String, Object?>.from(rawTrace))
          : null,
    );
  }

  final String type;
  final String message;
  final String timestamp;
  final ToolTrace? trace;
}
