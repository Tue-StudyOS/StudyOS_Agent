import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'prompt_context.dart';

class CloudAgentClient {
  CloudAgentClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<String> sendMessage({
    required AgentConfig config,
    required String apiKey,
    required List<ChatMessage> history,
    required String userText,
    required PromptContext context,
    required Future<void> Function(String text) appendMemory,
    required Future<String> Function() readMemory,
  }) async {
    final endpoint = Uri.tryParse(config.cloudEndpoint.trim());
    if (endpoint == null || !endpoint.hasScheme || !endpoint.hasAuthority) {
      throw const CloudAgentException('Cloud endpoint is not a valid URL.');
    }
    if (config.cloudModel.trim().isEmpty) {
      throw const CloudAgentException('Cloud model is required.');
    }
    if (apiKey.trim().isEmpty) {
      throw const CloudAgentException('Cloud API key is required.');
    }

    final request = _requestBody(
      config: config,
      history: history,
      userText: userText,
      context: context,
    );
    final response = await _post(endpoint, apiKey, request);
    final decoded = _decodeResponse(response);
    final message = _messageFromResponse(decoded);
    final toolCalls = _toolCalls(message);
    if (toolCalls.isNotEmpty) {
      final toolMessages = <Map<String, Object?>>[];
      for (final call in toolCalls) {
        final output = await _executeTool(
          call,
          context: context,
          appendMemory: appendMemory,
          readMemory: readMemory,
        );
        toolMessages.add(<String, Object?>{
          'role': 'tool',
          'tool_call_id': call.id,
          'content': output,
        });
      }
      final followUp = await _post(endpoint, apiKey, <String, Object?>{
        ...request,
        'messages': <Map<String, Object?>>[
          ...List<Map<String, Object?>>.from(request['messages'] as List),
          message,
          ...toolMessages,
        ],
      });
      return _contentFromMessage(
        _messageFromResponse(_decodeResponse(followUp)),
      );
    }

    return _contentFromMessage(message);
  }

  Future<http.Response> _post(
    Uri endpoint,
    String apiKey,
    Map<String, Object?> body,
  ) {
    return _httpClient.post(
      endpoint,
      headers: <String, String>{
        'Authorization': 'Bearer ${apiKey.trim()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }

  Map<String, Object?> _requestBody({
    required AgentConfig config,
    required List<ChatMessage> history,
    required String userText,
    required PromptContext context,
  }) {
    final historyWithoutCurrent =
        history.isNotEmpty &&
            history.last.isUser &&
            history.last.text.trim() == userText.trim()
        ? history.take(history.length - 1)
        : history;
    return <String, Object?>{
      'model': config.cloudModel.trim(),
      'messages': <Map<String, Object?>>[
        <String, Object?>{'role': 'system', 'content': context.systemPrompt()},
        for (final message in historyWithoutCurrent)
          if (message.text.trim().isNotEmpty)
            <String, Object?>{
              'role': message.isUser ? 'user' : 'assistant',
              'content': message.text,
            },
        <String, Object?>{'role': 'user', 'content': userText},
      ],
      'tools': _toolDefinitions(),
      'tool_choice': 'auto',
    };
  }

  Map<String, Object?> _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudAgentException(
        'Cloud provider returned HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const CloudAgentException('Cloud response was not a JSON object.');
    }
    return decoded;
  }

  Map<String, Object?> _messageFromResponse(Map<String, Object?> decoded) {
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const CloudAgentException(
        'Cloud response did not include choices.',
      );
    }
    final choice = Map<String, Object?>.from(choices.first as Map);
    final message = choice['message'];
    if (message is! Map) {
      throw const CloudAgentException(
        'Cloud response did not include content.',
      );
    }
    return Map<String, Object?>.from(message);
  }

  String _contentFromMessage(Map<String, Object?> message) {
    final content = message['content']?.toString();
    if (content == null || content.trim().isEmpty) {
      throw const CloudAgentException('Cloud response content was empty.');
    }
    return content;
  }

  List<_ToolCall> _toolCalls(Map<String, Object?> message) {
    final rawCalls = message['tool_calls'];
    if (rawCalls is! List) return const <_ToolCall>[];
    return rawCalls
        .whereType<Map>()
        .map((raw) {
          final call = Map<String, Object?>.from(raw);
          final function = call['function'];
          final functionMap = function is Map
              ? Map<String, Object?>.from(function)
              : const <String, Object?>{};
          return _ToolCall(
            id: call['id']?.toString() ?? '',
            name: functionMap['name']?.toString() ?? '',
            arguments: functionMap['arguments']?.toString() ?? '{}',
          );
        })
        .where((call) => call.id.isNotEmpty && call.name.isNotEmpty)
        .toList();
  }

  Future<String> _executeTool(
    _ToolCall call, {
    required PromptContext context,
    required Future<void> Function(String text) appendMemory,
    required Future<String> Function() readMemory,
  }) async {
    return switch (call.name) {
      'append_memory' => _appendMemory(call.arguments, appendMemory),
      'read_memories' => readMemory(),
      'get_study_context' => context.systemPrompt(),
      _ => 'Tool is not available: ${call.name}',
    };
  }

  Future<String> _appendMemory(
    String arguments,
    Future<void> Function(String text) appendMemory,
  ) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(arguments);
    } on FormatException {
      return 'Memory arguments were not valid JSON.';
    }
    if (decoded is! Map) return 'Memory text was not provided.';
    final text = Map<String, Object?>.from(decoded)['text']?.toString();
    if (text == null || text.trim().isEmpty) {
      return 'Memory text was not provided.';
    }
    await appendMemory(text);
    return 'Memory saved.';
  }

  List<Map<String, Object?>> _toolDefinitions() {
    return <Map<String, Object?>>[
      _tool(
        name: 'append_memory',
        description: 'Append a durable student memory to local device storage.',
        properties: <String, Object?>{
          'text': <String, Object?>{
            'type': 'string',
            'description': 'A concise memory worth keeping for future chats.',
          },
        },
        required: const <String>['text'],
      ),
      _tool(
        name: 'read_memories',
        description: 'Read the local long-term memory document.',
        properties: const <String, Object?>{},
        required: const <String>[],
      ),
      _tool(
        name: 'get_study_context',
        description: 'Read current profile, memory, and local study context.',
        properties: const <String, Object?>{},
        required: const <String>[],
      ),
    ];
  }

  Map<String, Object?> _tool({
    required String name,
    required String description,
    required Map<String, Object?> properties,
    required List<String> required,
  }) {
    return <String, Object?>{
      'type': 'function',
      'function': <String, Object?>{
        'name': name,
        'description': description,
        'parameters': <String, Object?>{
          'type': 'object',
          'properties': properties,
          'required': required,
        },
      },
    };
  }
}

class _ToolCall {
  const _ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final String arguments;
}

class CloudAgentException implements Exception {
  const CloudAgentException(this.message);

  final String message;

  @override
  String toString() => message;
}
