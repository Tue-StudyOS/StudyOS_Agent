import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cloud_tool_definitions.dart';
import 'mail_tools.dart';
import 'models.dart';
import 'native_tool_router.dart';
import 'prompt_context.dart';
import 'studyos_tool_catalog.dart';
import 'studyos_tool_executor.dart';

class CloudAgentClient {
  CloudAgentClient({
    http.Client? httpClient,
    StudyOsToolExecutor? toolExecutor,
    NativeToolRunner? nativeTools,
  }) : _httpClient = httpClient ?? http.Client(),
       _toolExecutor = toolExecutor ?? const StudyOsToolExecutor(),
       // Keep the public constructor parameter named `nativeTools`.
       // ignore: prefer_initializing_formals
       _nativeTools = nativeTools;

  final http.Client _httpClient;
  final StudyOsToolExecutor _toolExecutor;
  final NativeToolRunner? _nativeTools;

  Future<String> sendMessage({
    required AgentConfig config,
    required String apiKey,
    required List<ChatMessage> history,
    required String userText,
    required PromptContext context,
    required Future<void> Function(String text) appendMemory,
    required Future<String> Function() readMemory,
    required Future<String> Function() readSchedule,
    required MailToolRunner mailTools,
    void Function(ToolTrace trace)? onToolTrace,
  }) async {
    final endpoint = Uri.tryParse(config.cloudEndpoint.trim());
    if (endpoint == null || !endpoint.hasScheme || !endpoint.hasAuthority) {
      throw const CloudAgentException('Custom AI server URL is not valid.');
    }
    if (config.cloudModel.trim().isEmpty) {
      throw const CloudAgentException('Model name is required.');
    }
    if (apiKey.trim().isEmpty) {
      throw const CloudAgentException('API key is required.');
    }

    final supportedNativeToolNames =
        await _nativeTools?.supportedToolNames() ?? const <String>{};
    final request = _requestBody(
      config: config,
      history: history,
      userText: userText,
      context: context,
      supportedNativeToolNames: supportedNativeToolNames,
    );
    final response = await _post(endpoint, apiKey, request);
    final decoded = _decodeResponse(response);
    final message = _messageFromResponse(decoded);
    final toolCalls = _toolCalls(message);
    if (toolCalls.isEmpty) {
      return _contentFromMessage(message);
    }

    final toolMessages = <Map<String, Object?>>[];
    final toolContext = StudyOsToolContext(
      promptContext: context,
      appendMemory: appendMemory,
      readMemory: readMemory,
      readSchedule: readSchedule,
      mailTools: mailTools,
      nativeTools: _nativeTools,
    );
    for (final call in toolCalls) {
      onToolTrace?.call(_traceForCall(call, 'running'));
      final String output;
      try {
        output = await _toolExecutor.execute(
          call.name,
          call.arguments,
          toolContext,
        );
      } on Object catch (error) {
        onToolTrace?.call(
          _traceForCall(call, 'failed', output: error.toString()),
        );
        rethrow;
      }
      onToolTrace?.call(_traceForCall(call, 'done', output: output));
      toolMessages.add(<String, Object?>{
        'role': 'tool',
        'tool_call_id': call.id,
        'content': output,
      });
    }

    final followUp = await _post(endpoint, apiKey, <String, Object?>{
      'model': config.cloudModel.trim(),
      'messages': <Map<String, Object?>>[
        ...List<Map<String, Object?>>.from(request['messages'] as List),
        message,
        ...toolMessages,
      ],
    });
    return _contentFromMessage(_messageFromResponse(_decodeResponse(followUp)));
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
    required Set<String> supportedNativeToolNames,
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
          if (!message.isTrace && message.text.trim().isNotEmpty)
            <String, Object?>{
              'role': message.isUser ? 'user' : 'assistant',
              'content': message.text,
            },
        <String, Object?>{'role': 'user', 'content': userText},
      ],
      'tools': cloudToolDefinitions(
        supportedNativeToolNames: supportedNativeToolNames,
      ),
      'tool_choice': 'auto',
    };
  }

  Map<String, Object?> _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudAgentException(
        'Custom AI service returned HTTP ${response.statusCode}.',
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

  ToolTrace _traceForCall(_ToolCall call, String status, {String? output}) {
    final summary =
        studyOsToolByName(call.name)?.traceSummary ??
        'Requested unavailable tool.';
    final outputSuffix = output == null
        ? ''
        : ' Returned ${output.length} chars.';
    return ToolTrace(
      toolName: call.name,
      status: status,
      summary: '$summary$outputSuffix',
      callId: call.id,
    );
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
