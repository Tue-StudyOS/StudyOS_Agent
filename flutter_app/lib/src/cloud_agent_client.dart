import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class CloudAgentClient {
  CloudAgentClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<String> sendMessage({
    required AgentConfig config,
    required String apiKey,
    required List<ChatMessage> history,
    required String userText,
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

    final response = await _httpClient.post(
      endpoint,
      headers: <String, String>{
        'Authorization': 'Bearer ${apiKey.trim()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, Object?>{
        'model': config.cloudModel.trim(),
        'messages': <Map<String, String>>[
          for (final message in history)
            if (message.text.trim().isNotEmpty)
              <String, String>{
                'role': message.isUser ? 'user' : 'assistant',
                'content': message.text,
              },
          <String, String>{'role': 'user', 'content': userText},
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudAgentException(
        'Cloud provider returned HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const CloudAgentException('Cloud response was not a JSON object.');
    }
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
    final content = Map<String, Object?>.from(message)['content']?.toString();
    if (content == null || content.trim().isEmpty) {
      throw const CloudAgentException('Cloud response content was empty.');
    }
    return content;
  }
}

class CloudAgentException implements Exception {
  const CloudAgentException(this.message);

  final String message;

  @override
  String toString() => message;
}
